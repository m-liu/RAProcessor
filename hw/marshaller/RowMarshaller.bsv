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

typedef enum {READ, WRITE} Op deriving (Eq, Bits);
typedef Bit#(32) ROW_BURST;

typedef 32 MAX_COLS;
typedef 7 NUM_MODULES;
typedef 4 DDR_REQ_PER_ROW; //32 cols * 32 bits = 1024 bits; 1024/256 = 4
	
typedef struct {
	Bit#(31) rowAddr;
	Bit#(31) numRows;
	Bit#(4) reqSrc;
	Op op;
} ROW_REQ deriving (Eq,Bits);

interface ROW_ACCESS_IFC;
	method Action rowReq( ROW_REQ req);
	method ActionValue#( ROW_BURST ) readResp();
	method Action writeData ( ROW_BURST wData );
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
	FIFO#(ROW_REQ) rowReqQ <- mkFIFO;

	//separate data fifos for each module
	Vector#(NUM_MODULES, FIFO#(ROW_BURST)) dataIn <- replicateM (mkFIFO);
	Vector#(NUM_MODULES, FIFO#(ROW_BURST)) dataOut <- replicateM (mkFIFO);

	Reg#(State) state <- mkReg(READY);

	//Reg#(Bit#(16)) rowCounter <- mkReg(0); //counts up
	Reg#(DDR2Address) ddrCounter <- mkReg(0);
	Reg#(DDR2Address) ddrCounterOut <- mkReg(0);
	Reg#(Bit#(4)) rburstCounter <- mkReg(0);
	Reg#(Bit#(4)) wburstCounter <- mkReg(0);
	Reg#(Bit#(256)) wdataBuff <- mkReg(0);

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
			Bit#(256) resp = ddrResp.first();
			//send out in 8 burst of 32 bits
			if (rburstCounter < 8) begin
				Bit#(256) resp_shift = resp >> rburstCounter;
				dataOut[currReq.reqSrc].enq(truncate(resp_shift));
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
			if (wburstCounter < 8) begin
				dataIn[currReq.reqSrc].deq();
				//assemble write data
				wdataBuff <= (wdataBuff<<32) | zeroExtend(dataIn[currReq.reqSrc].first());
				wburstCounter <= wburstCounter+1;
			end
			else begin
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
							method Action rowReq ( ROW_REQ req );
								rowReqQ.enq(req);
							endmethod
							
							method ActionValue#( ROW_BURST ) readResp();
								dataOut[moduleInd].deq();
								return dataOut[moduleInd].first();
							endmethod

							method Action writeData ( ROW_BURST wData );
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
