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

interface ROW_ACCESS_IFC;
	method Action rowReq( RowReq req);
	method ActionValue#( RowBurst ) readResp();
	method Action writeData ( RowBurst wData );
endinterface

interface ROW_MARSHALLER_IFC;
	interface Vector#(NUM_MODULES, ROW_ACCESS_IFC) rowAccesses;
	interface DDR2Client ddrMem;
endinterface

typedef enum {READY, READ_DDR, WRITE_DDR} State deriving (Eq, Bits);



//********************
//Module
//********************

module mkRowMarshaller(ROW_MARSHALLER_IFC);

	
	//********************
	//State elements
	//********************
	
	FIFO#(DDR2Request) ddrReq <- mkFIFO;
	FIFO#(DDR2Response) ddrResp <- mkFIFO;

	//all req enq into the same req fifo
	FIFO#(RowReq) rowReqQ <- mkFIFO;

	//separate data fifos for each module
	Vector#(NUM_MODULES, FIFO#(RowBurst)) dataIn <- replicateM (mkFIFO);
	Vector#(NUM_MODULES, FIFO#(RowBurst)) dataOut <- replicateM (mkFIFO);

	Reg#(State) state <- mkReg(READY);

	//Reg#(Bit#(16)) rowCounter <- mkReg(0); //counts up
	Reg#(DDR2Address) ddrCounter <- mkReg(0);
	Reg#(DDR2Address) ddrCounterOut <- mkReg(0);
	Reg#(Bit#(32)) rburstCounter <- mkReg(0);
	Reg#(Bit#(32)) wburstCounter <- mkReg(0);
	Reg#(DDR2Data) wdataBuff <- mkReg(0);

	//********************
	//Rules
	//********************
	let currReq = rowReqQ.first();
	//The DDR addr stop at. DDR2 is 64-bit addressible, in bursts of 4.
	let ddrStartAddr  = (currReq.rowAddr) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));
	let ddrStopAddr = (currReq.rowAddr + currReq.numRows) << (2 + log2(valueOf(DDR_REQ_PER_ROW)));

	rule acceptReq if (state == READY);
		ddrCounter <= ddrStartAddr;
		ddrCounterOut <= ddrStartAddr;
		if (currReq.op == READ) begin
			state <= READ_DDR;
			$display("Marsh: acceptReq READ ddrStart=%x, ddrStop=%x", ddrStartAddr, ddrStopAddr);
		end
		else begin //WRITE
			state <= WRITE_DDR;
			$display("Marsh: acceptReq WRITE ddrStart=%x, ddrStop=%x", ddrStartAddr, ddrStopAddr);
		end	
	endrule

	rule reqReadDDR if (state == READ_DDR && ddrCounter < ddrStopAddr);
		ddrReq.enq(DDR2Request{ writeen: 0,
								address: ddrCounter,
								datain: ? //ignored for reads
							});
		ddrCounter <= ddrCounter + 4; //4 bursts of 64 bits
	endrule

	rule readDDR if (state == READ_DDR);
		if (ddrCounterOut < ddrStopAddr) begin
			DDR2Data resp = ddrResp.first();
			//$display("Marsh: ddr chunk: %x", resp);
			//send out in 8 burst of 32 bits
			if (rburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA))) begin
				DDR2Data resp_shift = resp << (rburstCounter<< valueOf(TLog#(BURST_WIDTH))); //shift by 32
				dataOut[currReq.reqSrc].enq(truncateLSB(resp_shift));
				//$display("Marsh: ddr chunk shifted: %x", resp_shift);
				RowBurst dataR = truncate(resp_shift);
				//$display("Marsh: reading data %x, burstCount=%d", dataR, rburstCounter);
				rburstCounter <= rburstCounter+1;
			end
			else begin	//done with bursting a DDR response
				ddrResp.deq();
				rburstCounter <= 0;
				ddrCounterOut <= ddrCounterOut + 4;
			end
		end
		else begin //done with all DDR responses
			rowReqQ.deq();
			state <= READY;
		end
		
	endrule

	rule reqWriteDDR if (state == WRITE_DDR);
		if (ddrCounter < ddrStopAddr) begin
			if (wburstCounter < fromInteger(valueOf(BURSTS_PER_DDR_DATA))) begin
				dataIn[currReq.reqSrc].deq();
				//assemble write data
				wdataBuff <= (wdataBuff<< valueOf(BURST_WIDTH)) | zeroExtend(dataIn[currReq.reqSrc].first());
				wburstCounter <= wburstCounter+1;
			end
			else begin
				$display("Marsh: writing ddr data: %x", wdataBuff);
				ddrReq.enq(DDR2Request{ writeen: 32'hFFFFFFFF,
										address: ddrCounter,
										datain: wdataBuff
									});
				ddrCounter <= ddrCounter + 4; //4 bursts of 64 bits
				wburstCounter <= 0;
			end
		end
		else begin
			rowReqQ.deq();
			state <= READY;
		end
	endrule


	
	//********************
	//Interface definition
	//********************

	//a vector of interfaces 
	Vector#(NUM_MODULES, ROW_ACCESS_IFC) rowAcc = newVector();

	for (Integer moduleInd = 0; moduleInd < valueOf(NUM_MODULES); moduleInd=moduleInd+1) 
	begin
		rowAcc[moduleInd] =interface ROW_ACCESS_IFC; 
							method Action rowReq ( RowReq req );
								rowReqQ.enq(req);
							endmethod
							
							method ActionValue#( RowBurst ) readResp();
								dataOut[moduleInd].deq();
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
