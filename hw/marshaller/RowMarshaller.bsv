//row marshaller to assemble ddr bursts into table rows

import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import DDR2::*;

//**********
//Defines
//**********
//typedef enum { DATA_IO, UNION, DIFFERENCE, SELECTION, PROJECTION, XPROD, DEDUP } ReqSrc deriving (Bits);
//Unfortunately enums do not work for indexing vectors. Must use defines
typedef 0 DATA_IO_BLK;
typedef 1 UNION_BLK;
typedef 2 DIFFERENCE_BLK;
typedef 3 SELECTION_BLK;
typedef 4 PROJECTION_BLK;
typedef 5 XPROD_BLK;
typedef 6 DEDUP_BLK;

typedef enum {READ, WRITE} MemOp deriving (Eq, Bits);
typedef enum {REQ_ALLROWS, REQ_NROWS, REQ_EOT} RowReqType deriving (Eq, Bits);

typedef 7 NUM_MODULES;
typedef 32 BURST_WIDTH;
typedef 32 COL_WIDTH;
typedef 32 MAX_COLS;
typedef 256 DDR_DATA_WIDTH;
typedef TMul#(COL_WIDTH, MAX_COLS) ROW_BITS;
typedef TDiv#(ROW_BITS, BURST_WIDTH) BURSTS_PER_ROW; //32
typedef TDiv#(DDR_DATA_WIDTH, BURST_WIDTH) BURSTS_PER_DDR_DATA; //8
typedef TDiv#(ROW_BITS, DDR_DATA_WIDTH) DDR_REQ_PER_ROW; //32 cols * 32 bits = 1024 bits; 1024/256 = 4
typedef TDiv#(DDR_DATA_WIDTH, COL_WIDTH) COLS_PER_DDR_DATA; //8
typedef TDiv#(COL_WIDTH, BURST_WIDTH) COLS_PER_BURST; //1
typedef TDiv#(BURST_WIDTH, 8) BURST_WIDTH_BYTES; //32/8=4

typedef Bit#(31) RowAddr;
typedef Bit#(BURST_WIDTH) RowBurst;
typedef Bit#(TMul#(MAX_COLS,BURST_WIDTH)) Row; //32*32
	
typedef struct {
	RowAddr tableAddr; 	//start addr of table
	RowAddr rowOffset;	//which row of the table to start r/w
	RowAddr numRows;	//how many rows to r/w
	RowAddr numCols;	//num of cols of table
	Bit#(4) reqSrc;		//which operator the req came from
	RowReqType reqType;	//r/w all rows or nrows
	MemOp op;			//r/w
} RowReq deriving (Eq,Bits);

interface ROW_ACCESS_SERVER_IFC;
	method Action rowReq (RowReq req);
	method ActionValue#(RowBurst) readResp();
	method Action writeData (RowBurst wData);
endinterface

interface ROW_ACCESS_CLIENT_IFC;
	method ActionValue#(RowReq) rowReq();
	method Action readResp (RowBurst rData);
	method ActionValue#(RowBurst) writeData();
endinterface


interface ROW_MARSHALLER_IFC;
	interface Vector#(NUM_MODULES, ROW_ACCESS_SERVER_IFC) rowAccesses;
	interface DDR2Client ddrMem;
endinterface

typedef enum {READY, READ_DDR, WRITE_DDR, READ_DDR_ALLROWS} State deriving (Eq, Bits);



//********************
//Row Marshaller Module
//********************
(* synthesize *)
module mkRowMarshaller(ROW_MARSHALLER_IFC);

	
	//********************
	//State elements
	//********************
	
	FIFO#(DDR2Request) ddrReq <- mkFIFO;
	FIFO#(DDR2Response) ddrResp <- mkFIFO;

	//req queues 
	FIFO#(RowReq) rowReadReqQ <- mkFIFO;
	FIFO#(RowReq) rowWriteReqQ <- mkFIFO;

	//separate data fifos for each module
	Vector#(NUM_MODULES, FIFO#(RowBurst)) dataIn <- replicateM (mkSizedFIFO(2*valueOf(BURSTS_PER_ROW)));
	Vector#(NUM_MODULES, FIFO#(RowBurst)) dataOut <- replicateM (mkSizedFIFO(2*valueOf(BURSTS_PER_ROW)));
//	Reg#(Bit#(32)) dataOutEmptyCnt <- mkReg(fromInteger(2*valueOf(BURSTS_PER_ROW))); //initialize to size of dataOut
	Reg#(Bit#(32)) dataOutEnqCnt <- mkReg(0); 
	Reg#(Bit#(32)) dataOutDeqCnt <- mkReg(0); 
	//Reg#(Bit#(32)) dataOutDeqCnt <- mkReg(fromInteger(2*valueOf(BURSTS_PER_ROW))); //initialize to size of dataOut

	Reg#(State) rState <- mkReg(READY);
	Reg#(State) wState <- mkReg(READY);

	//Reg#(Bit#(16)) rowCounter <- mkReg(0); //counts up
	Reg#(DDR2Address) rDdrCounter <- mkReg(0);
	Reg#(DDR2Address) rDdrCounterOut <- mkReg(0);
	Reg#(DDR2Address) wDdrCounter <- mkReg(0);
	Reg#(DDR2Address) wDdrCounterOut <- mkReg(0);
	Reg#(Bit#(32)) rburstCounter <- mkReg(0);
	Reg#(Bit#(32)) wburstCounter <- mkReg(0);
	Reg#(DDR2Data) wdataBuff <- mkReg(0);
	Reg#(Bit#(32)) wdataEn <- mkReg(0);

	Reg#(Bool) endOfTable <- mkReg(False);

	//********************
	//Rules
	//********************
	let currReadReq = rowReadReqQ.first();
	let currWriteReq = rowWriteReqQ.first();

	//The DDR addr stop at. DDR2 is 64-bit addressible, in bursts of 4.

	//compute the table start addr in DDR
	//assumed worst case TODO, aligned
	let rTableAddrDDR = (currReadReq.tableAddr) << (2 + log2(valueOf(DDR_REQ_PER_ROW))); 
	//compute where to start/stop issuing ddr req
	let rDdrStartAddr = rTableAddrDDR + ((currReadReq.rowOffset * currReadReq.numCols) >> valueOf(TLog#(COLS_PER_DDR_DATA)) <<  2);
	//Note: taking the ceiling here
	let rStopEntryOffset = (currReadReq.rowOffset+currReadReq.numRows) * currReadReq.numCols + (fromInteger(valueOf(COLS_PER_DDR_DATA))-1);
	let rDdrStopAddr = rTableAddrDDR + (rStopEntryOffset >> valueOf(TLog#(COLS_PER_DDR_DATA)) <<  2);
	//compute the offsets within a DDR response for the first/last response
	Bit#(TLog#(COLS_PER_DDR_DATA)) rDdrStartOffset = truncate(currReadReq.rowOffset*currReadReq.numCols);
	Bit#(TLog#(COLS_PER_DDR_DATA)) rDdrStopOffset = truncate( ((currReadReq.rowOffset+currReadReq.numRows)*currReadReq.numCols)-1 );


//	let rDdrStartAddr  = (currReadReq.rowAddr) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));
//	let rDdrStopAddr = (currReadReq.rowAddr + currReadReq.numRows) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));
	//let wDdrStartAddr  = (currWriteReq.rowOffset) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));
	//let wDdrStopAddr = (currWriteReq.rowOffset + currWriteReq.numRows) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));

	let wTableAddrDDR = (currWriteReq.tableAddr) << (2 + log2(valueOf(DDR_REQ_PER_ROW))); //assumed worst case TODO, aligned
	let wDdrStartAddr = wTableAddrDDR + ((currWriteReq.rowOffset * currWriteReq.numCols) >> valueOf(TLog#(COLS_PER_DDR_DATA)) <<  2);
	//Note: taking the ceiling here
	let wStopEntryOffset = (currWriteReq.rowOffset+currWriteReq.numRows) * currWriteReq.numCols + (fromInteger(valueOf(COLS_PER_DDR_DATA))-1);
	let wDdrStopAddr = wTableAddrDDR + (wStopEntryOffset >> valueOf(TLog#(COLS_PER_DDR_DATA)) <<  2);
	Bit#(TLog#(COLS_PER_DDR_DATA)) wDdrStartOffset = truncate(currWriteReq.rowOffset*currWriteReq.numCols);
	Bit#(TLog#(COLS_PER_DDR_DATA)) wDdrStopOffset = truncate( ((currWriteReq.rowOffset+currWriteReq.numRows)*currWriteReq.numCols)-1 );

	Bit#(32) dataOutFullCnt = dataOutEnqCnt - dataOutDeqCnt;
	Bit#(32) dataOutEmptyCnt = fromInteger(2*valueOf(BURSTS_PER_ROW)) - dataOutFullCnt;


	rule acceptReadReq if (rState == READY);
		if (currReadReq.reqType == REQ_ALLROWS) begin
			rDdrCounter <= rDdrStartAddr;
			rDdrCounterOut <= rDdrStartAddr;
			rState <= READ_DDR_ALLROWS;
			endOfTable <= False;
			$display("Marsh: acceptReq READ ALL ROWS ddrStart=%x", rDdrStartAddr);
		end
		else begin //REQ_NROWS
			rDdrCounter <= rDdrStartAddr;
			rDdrCounterOut <= rDdrStartAddr;
			rState <= READ_DDR;
			$display("Marsh: acceptReq READ ddrStart=%x, ddrStop=%x, ddrStartOff=%d, ddrStopOff=%d", rDdrStartAddr, rDdrStopAddr, rDdrStartOffset, rDdrStopOffset);
		end
		rburstCounter <= 0;
	endrule

	//*************************************
	//Rules to read all rows of a table
	//*************************************

	rule reqReadDDRAllRows if (rState == READ_DDR_ALLROWS &&
								endOfTable == False &&
								dataOutEmptyCnt >= fromInteger(valueOf(BURSTS_PER_DDR_DATA)));
		$display("Marsh: read [ALLROWS] req DDR at addr=%x", rDdrCounter);
		ddrReq.enq(DDR2Request{ writeen: 0,
								address: rDdrCounter,
								datain: ? //ignored for reads
							});
		rDdrCounter <= rDdrCounter + 4; //4 bursts of 64 bits
		//subtract to get many slots will be available in the fifo after this req
		dataOutEnqCnt <= dataOutEnqCnt + fromInteger(valueOf(BURSTS_PER_DDR_DATA));
		$display("dataOutEnqCnt=%d, deqcnt=%d", dataOutEnqCnt, dataOutDeqCnt);
	endrule

	//IMPORTANT: always drain the read data before making more requests
	(* descending_urgency = "readDDRAllRows, reqReadDDRAllRows" *)
	rule readDDRAllRows if (rState == READ_DDR_ALLROWS);
		if (endOfTable == False) begin
		//if (rDdrCounterOut < rDdrCounter) begin //TODO this may be a problem if we can't issue req fast enough
			DDR2Data resp = ddrResp.first();
			$display("DDR response AR: %x", resp);
			//send out in 8 burst of 32 bits
			if (rburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA))) begin
				DDR2Data resp_shift = resp << (rburstCounter<< valueOf(TLog#(BURST_WIDTH))); //shift by 32
				
				RowBurst truncRespShift = truncateLSB(resp_shift);
				
				//all 1's, end of table reached
				if ( reduceAnd(truncRespShift) == 1 ) begin
					endOfTable <= True;
					dataOut[currReadReq.reqSrc].enq(truncRespShift);
					$display("Marsh AR: reading (last) data %x, burstCount=%d", truncRespShift, rburstCounter);
					ddrResp.deq();
					rDdrCounterOut <= rDdrCounterOut + 4;
					$display("End of table reached, cntOut=%d, cnt=%d", rDdrCounterOut+4, rDdrCounter);
				end
				//If first DDR response, start enq at offset
				else if (rDdrCounterOut > rDdrStartAddr || rburstCounter >= zeroExtend(rDdrStartOffset)) begin
					dataOut[currReadReq.reqSrc].enq(truncRespShift);
					$display("Marsh AR: ddr chunk shifted: %x", resp_shift);
					$display("Marsh AR: reading data %x, burstCount=%d", truncRespShift, rburstCounter);
				end
				//skip the burst
				else begin 
					$display("Marsh AR: skipped burst");
				end

				rburstCounter <= rburstCounter+1;
			end
			else begin	//done with bursting a DDR response
				$display("Marsh AR: done with ddr response");
				ddrResp.deq();
				rburstCounter <= 0;
				rDdrCounterOut <= rDdrCounterOut + 4;
			end
		end

		//drain the rest of the responses
		else if (endOfTable == True && rDdrCounterOut < rDdrCounter) begin
			$display("Marsh AR: drained DDR burst");
			ddrResp.deq();
			rDdrCounterOut <= rDdrCounterOut + 4;
		end
		else begin //done with all DDR responses
			$display("Marsh AR: DONE READ");
			rowReadReqQ.deq();
			rState <= READY;
		end
	endrule


	//*************************************
	//Rules to read N rows of a table
	//*************************************

	rule reqReadDDR if (rState == READ_DDR && 
						rDdrCounter < rDdrStopAddr && 
						dataOutEmptyCnt >= fromInteger(valueOf(BURSTS_PER_DDR_DATA)));

		$display("Marsh: read req DDR at addr=%x", rDdrCounter);
		ddrReq.enq(DDR2Request{ writeen: 0,
								address: rDdrCounter,
								datain: ? //ignored for reads
							});
		rDdrCounter <= rDdrCounter + 4; //4 bursts of 64 bits
		//subtract to get many slots will be available in the fifo after this req
		dataOutEnqCnt <= dataOutEnqCnt + fromInteger(valueOf(BURSTS_PER_DDR_DATA));
		$display("dataOutEnqCnt=%d, deqcnt=%d", dataOutEnqCnt, dataOutDeqCnt);
	endrule

	//IMPORTANT: always drain the read data before making more requests
	(* descending_urgency = "readDDR, reqReadDDR" *)
	rule readDDR if (rState == READ_DDR);
		if (rDdrCounterOut < rDdrStopAddr) begin
			DDR2Data resp = ddrResp.first();
			$display("DDR response: %x", resp);
			//$display("Marsh: ddr chunk: %x", resp);
			//send out in 8 burst of 32 bits
			if (rburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA))) begin
				DDR2Data resp_shift = resp << (rburstCounter<< valueOf(TLog#(BURST_WIDTH))); //shift by 32

				//If first DDR response, start enq at offset
				if ( (rDdrCounterOut > rDdrStartAddr || rburstCounter >= zeroExtend(rDdrStartOffset)) &&
					 (rDdrCounterOut+4 < rDdrStopAddr || rburstCounter <= zeroExtend(rDdrStopOffset))) begin
					dataOut[currReadReq.reqSrc].enq(truncateLSB(resp_shift));
					$display("Marsh: ddr chunk shifted: %x", resp_shift);
					RowBurst dataR = truncateLSB(resp_shift);
					$display("Marsh: reading data %x, burstCount=%d", dataR, rburstCounter);
				end
				rburstCounter <= rburstCounter+1;
			end
			else begin	//done with bursting a DDR response
				ddrResp.deq();
				rburstCounter <= 0;
				rDdrCounterOut <= rDdrCounterOut + 4;
			end
		end
		else begin //done with all DDR responses
			rowReadReqQ.deq();
			rState <= READY;
			$display("Marsh: done with all DDR responses");
		end
		
	endrule



	//*************************************
	//Rules to write N rows of a table
	//*************************************
	rule acceptWriteReq if (wState == READY);
		wDdrCounter <= wDdrStartAddr;
		wDdrCounterOut <= wDdrStartAddr;
		
		//set the starting burst counter for the first row
		wburstCounter <= zeroExtend(wDdrStartOffset);

		wState <= WRITE_DDR;
		$display("Marsh: acceptReq WRITE ddrStart=%x, ddrStop=%x, offsetStart=%d, offsetStop=%d", wDdrStartAddr, wDdrStopAddr, wDdrStartOffset, wDdrStopOffset);
	endrule



	//IMPORTANT: prioritize writes over reads. This ensures no deadlock occurs. 
	//Results will always drain
	(* descending_urgency = "reqWriteDDR, reqReadDDR, reqReadDDRAllRows" *)
	//(* descending_urgency = "reqReadDDR, reqWriteDDR" *)
	rule reqWriteDDR if (wState == WRITE_DDR);
		if (wDdrCounter < wDdrStopAddr) begin

			//if it's the last row, send the ddr req when the last burst arrives;
			//don't wait for alignment
//			if (  (wburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA)) && wDdrCounter+4 < wDdrStopAddr) ||
//		   		  (wburstCounter <= zeroExtend(wDdrStopOffset)) ) begin
			if (  wburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA)) ) begin

				Bit#(BURST_WIDTH_BYTES) en = -1;
				//write end of table marker
				if (currWriteReq.reqType == REQ_EOT) begin
					if (wDdrCounter+4 < wDdrStopAddr || wburstCounter <= zeroExtend(wDdrStopOffset)) begin
						RowBurst data = -1;
						//assemble write data
						wdataBuff <= (wdataBuff<< valueOf(BURST_WIDTH)) | zeroExtend(data);
						//assemble the write enable
						wdataEn <= wdataEn << valueOf(BURST_WIDTH_BYTES) | zeroExtend(en);
					end
					else begin
						wdataBuff <= (wdataBuff<< valueOf(BURST_WIDTH));
						wdataEn <= wdataEn << valueOf(BURST_WIDTH_BYTES);
					end
				end
				else begin
					if (wDdrCounter+4 < wDdrStopAddr || wburstCounter <= zeroExtend(wDdrStopOffset)) begin
						dataIn[currWriteReq.reqSrc].deq();
						let data = dataIn[currWriteReq.reqSrc].first();
						//assemble write data
						wdataBuff <= (wdataBuff<< valueOf(BURST_WIDTH)) | zeroExtend(data);
						//assemble the write enable
						wdataEn <= wdataEn << valueOf(BURST_WIDTH_BYTES) | zeroExtend(en);
					end
					else  begin
						wdataBuff <= (wdataBuff<< valueOf(BURST_WIDTH));
						wdataEn <= wdataEn << valueOf(BURST_WIDTH_BYTES);
					end
				end

				wburstCounter <= wburstCounter+1;
			end
			else begin
				$display("Marsh: writing ddr addr: %x, data: %x, en: %x", wDdrCounter, wdataBuff, wdataEn);
				ddrReq.enq(DDR2Request{ writeen: wdataEn,
										//writeen: 'hFFFFFFFF,
										address: wDdrCounter,
										datain: wdataBuff
									});
				wDdrCounter <= wDdrCounter + 4; //4 bursts of 64 bits
				wburstCounter <= 0;
				wdataEn <= 0;
				wdataBuff <= 0;
			end
		end
		else begin
			rowWriteReqQ.deq();
			wState <= READY;
		end
	endrule


	
	//********************
	//Interface definition
	//********************

	//a vector of interfaces 
	Vector#(NUM_MODULES, ROW_ACCESS_SERVER_IFC) rowAcc = newVector();

	for (Integer moduleInd = 0; moduleInd < valueOf(NUM_MODULES); moduleInd=moduleInd+1) 
	begin
		rowAcc[moduleInd] =interface ROW_ACCESS_SERVER_IFC; 
							method Action rowReq ( RowReq req );
								if (req.op == READ) begin
									rowReadReqQ.enq(req);
								end
								else begin
									rowWriteReqQ.enq(req);
								end
							endmethod
							
							method ActionValue#( RowBurst ) readResp();
								dataOut[moduleInd].deq();
								dataOutDeqCnt <= dataOutDeqCnt + 1;
								return dataOut[moduleInd].first();
							endmethod

							method Action writeData ( RowBurst wData );
								dataIn[moduleInd].enq(wData);
							endmethod
						endinterface;
	end

	interface rowAccesses = rowAcc;

	interface DDR2Client ddrMem;
		interface Get request = toGet(ddrReq);
		interface Put response = toPut(ddrResp);
	endinterface 


endmodule



//*******************************************************************
// Define the client/server connection of the ROW_ACCESS interface
//*******************************************************************

instance Connectable#(ROW_ACCESS_SERVER_IFC, ROW_ACCESS_CLIENT_IFC);
	module mkConnection#(ROW_ACCESS_SERVER_IFC serv, ROW_ACCESS_CLIENT_IFC cli)(Empty);
		mkConnection(serv.rowReq, cli.rowReq);
		mkConnection(cli.readResp, serv.readResp);
		mkConnection(serv.writeData, cli.writeData);
	endmodule
endinstance




