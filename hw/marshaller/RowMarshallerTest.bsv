import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import RowMarshaller::*;
import XilinxDDR2::*; 
import DDR2::*;


typedef enum { TEST_IDLE, TEST_REQ, TEST_WR, TEST_RD, TEST_DONE } TestState deriving (Eq, Bits);


//typedef 3 SEL_OP;
typedef 5 NUM_TESTS;

module mkRowMarshallerTest();
	DDR2_User ddrServer <- mkDDR2Simulator();
	ROW_MARSHALLER_IFC marsh <- mkRowMarshaller();
	
	//connect ddr and marshaller
	mkConnection(marsh.ddrMem, ddrServer);

	//states
	Reg#(TestState) state <- mkReg(TEST_IDLE);
	Reg#(Bit#(31)) brCount <- mkReg(0);
	Reg#(Bit#(32)) reqInd <- mkReg(0);

	//data
	Reg#(RowBurst) someData <- mkReg(32'hDEADBEEF);
	//Reg#(RowBurst) someData <- mkReg('hFFFFFFE5);

	//Requests
	Vector#(NUM_TESTS, RowReq) testReq = newVector();
	testReq[0] = RowReq{ 	tableAddr: 23,
							rowOffset: 0,
						  	numRows: 5,
							//numCols: fromInteger(valueOf(MAX_COLS)), 
							numCols: 7, 
							reqSrc: fromInteger(valueOf(SELECTION_BLK)),
							reqType: REQ_NROWS,
							op: WRITE };
	
	testReq[1] = RowReq{ 	tableAddr: 23,
							rowOffset: 5,
						  	numRows: 8,
							//numCols: fromInteger(valueOf(MAX_COLS)), 
							numCols: 7, 
							reqSrc: fromInteger(valueOf(SELECTION_BLK)),
							reqType: REQ_EOT,
							op: WRITE };


	testReq[2] = RowReq{ 	tableAddr: 23,
							rowOffset: 0,
						  	numRows: ?,
							numCols: fromInteger(valueOf(MAX_COLS)),
							reqSrc: fromInteger(valueOf(SELECTION_BLK)),
							reqType: REQ_ALLROWS,
							op: READ };

	testReq[3] = RowReq{ 	tableAddr: 23,
							rowOffset: 0,
						  	numRows: 3,
							numCols: 5,
							reqSrc: fromInteger(valueOf(SELECTION_BLK)),
							reqType: REQ_NROWS,
							op: READ };
	
	testReq[4] = RowReq{ 	tableAddr: 23,
							rowOffset: 3,
						  	numRows: 10,
							numCols: fromInteger(valueOf(MAX_COLS)), 
							reqSrc: fromInteger(valueOf(SELECTION_BLK)),
							reqType: ?,
							op: WRITE };

	//send some requests
	let currReq = testReq[reqInd];
	rule sendReqs if (state==TEST_IDLE);
		if (reqInd < fromInteger(valueOf(NUM_TESTS))) begin
		
			$display("TB: sending req ind=%d", reqInd);

			marsh.rowAccesses[currReq.reqSrc].rowReq(currReq);
			if (currReq.op ==WRITE && currReq.reqType != REQ_EOT) begin
				state <= TEST_WR;
			end
			else if (currReq.op==READ) begin
				state <= TEST_RD;
			end
			else if (currReq.op==WRITE && currReq.reqType == REQ_EOT) begin
				reqInd <= reqInd+1;
				state <= TEST_IDLE;
			end
		end
		else begin
			$finish;
		end
	endrule

	rule burstingWR if (state==TEST_WR);
		$display("wburst [%d]: %x", brCount, someData);
		marsh.rowAccesses[currReq.reqSrc].writeData (someData);
		if (someData < 'hFFFFFFFF) begin
			someData <= someData+1;
		end

		if (brCount == (currReq.numRows*currReq.numCols * fromInteger(valueOf(COLS_PER_BURST)))-1) begin
			brCount <= 0;
			state <= TEST_IDLE;
			reqInd <= reqInd+1;
			$display("TB: done sending bursts");
			$display("******************");
		end
		else begin
			brCount <= brCount+1;
		end
	endrule

	rule burstingRD if (state==TEST_RD);
		let rburst <- marsh.rowAccesses[currReq.reqSrc].readResp;
		$display("rburst [%d]: %x", brCount, rburst);
		let totalBursts = currReq.numRows * currReq.numCols * fromInteger(valueOf(COLS_PER_BURST));

		if (currReq.reqType == REQ_ALLROWS) begin
			if (reduceAnd(rburst) == 1) begin
			//if (brCount == currReq.numRows*32-1) begin
				state <= TEST_IDLE;
				reqInd <= reqInd+1;
				$display("TB AR: done reading bursts");
				$display("******************");
			end
		end
		else begin
			if (brCount == totalBursts-1) begin
			//if (brCount == currReq.numRows*32-1) begin
				brCount <= 0;
				state <= TEST_IDLE;
				reqInd <= reqInd+1;
				$display("TB: done reading bursts");
				$display("******************");
			end
			else begin
				brCount <= brCount+1;
			end
		end
	endrule
	
endmodule
