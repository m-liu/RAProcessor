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

typedef 7 NUM_MODULES;
typedef 32 BURST_WIDTH;
typedef 32 COL_WIDTH;
typedef 32 MAX_COLS;
typedef 256 DDR_DATA_WIDTH;
typedef TMul#(COL_WIDTH, MAX_COLS) ROW_BITS;
typedef TDiv#(ROW_BITS, BURST_WIDTH) BURSTS_PER_ROW; //32
typedef TDiv#(DDR_DATA_WIDTH, BURST_WIDTH) BURSTS_PER_DDR_DATA; //8
typedef TDiv#(ROW_BITS, DDR_DATA_WIDTH) DDR_REQ_PER_ROW; //32 cols * 32 bits = 1024 bits; 1024/256 = 4

typedef Bit#(31) RowAddr;
typedef Bit#(BURST_WIDTH) RowBurst;
typedef Bit#(TMul#(MAX_COLS,BURST_WIDTH)) Row; //32*32
	
typedef struct {
	RowAddr rowAddr;
	RowAddr numRows;
	Bit#(4) reqSrc;
	MemOp op;
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

typedef enum {READY, READ_DDR, WRITE_DDR} State deriving (Eq, Bits);



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

	//********************
	//Rules
	//********************
	let currReadReq = rowReadReqQ.first();
	let currWriteReq = rowWriteReqQ.first();

	//The DDR addr stop at. DDR2 is 64-bit addressible, in bursts of 4.
	let rDdrStartAddr  = (currReadReq.rowAddr) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));
	let rDdrStopAddr = (currReadReq.rowAddr + currReadReq.numRows) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));

	let wDdrStartAddr  = (currWriteReq.rowAddr) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));
	let wDdrStopAddr = (currWriteReq.rowAddr + currWriteReq.numRows) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));

	Bit#(32) dataOutFullCnt = dataOutEnqCnt - dataOutDeqCnt;
	Bit#(32) dataOutEmptyCnt = fromInteger(2*valueOf(BURSTS_PER_ROW)) - dataOutFullCnt;


	rule acceptReadReq if (rState == READY);
		rDdrCounter <= rDdrStartAddr;
		rDdrCounterOut <= rDdrStartAddr;
		rState <= READ_DDR;
		$display("Marsh: acceptReq READ ddrStart=%x, ddrStop=%x", rDdrStartAddr, rDdrStopAddr);
	endrule

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
			//$display("Marsh: ddr chunk: %x", resp);
			//send out in 8 burst of 32 bits
			if (rburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA))) begin
				DDR2Data resp_shift = resp << (rburstCounter<< valueOf(TLog#(BURST_WIDTH))); //shift by 32
				dataOut[currReadReq.reqSrc].enq(truncateLSB(resp_shift));
				//$display("Marsh: ddr chunk shifted: %x", resp_shift);
				RowBurst dataR = truncate(resp_shift);
				//$display("Marsh: reading data %x, burstCount=%d", dataR, rburstCounter);
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
		end
		
	endrule


	rule acceptWriteReq if (wState == READY);
		wDdrCounter <= wDdrStartAddr;
		wDdrCounterOut <= wDdrStartAddr;
		wState <= WRITE_DDR;
		$display("Marsh: acceptReq WRITE ddrStart=%x, ddrStop=%x", wDdrStartAddr, wDdrStopAddr);
	endrule



	//IMPORTANT: prioritize writes over reads. This ensures no deadlock occurs. 
	//Results will always drain
	(* descending_urgency = "reqWriteDDR, reqReadDDR" *)
	//(* descending_urgency = "reqReadDDR, reqWriteDDR" *)
	rule reqWriteDDR if (wState == WRITE_DDR);
		if (wDdrCounter < wDdrStopAddr) begin
			if (wburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA))) begin
				dataIn[currWriteReq.reqSrc].deq();
				//assemble write data
				wdataBuff <= (wdataBuff<< valueOf(BURST_WIDTH)) | zeroExtend(dataIn[currWriteReq.reqSrc].first());
				wburstCounter <= wburstCounter+1;
			end
			else begin
				$display("Marsh: writing ddr data: %x", wdataBuff);
				ddrReq.enq(DDR2Request{ writeen: 32'hFFFFFFFF,
										address: wDdrCounter,
										datain: wdataBuff
									});
				wDdrCounter <= wDdrCounter + 4; //4 bursts of 64 bits
				wburstCounter <= 0;
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




