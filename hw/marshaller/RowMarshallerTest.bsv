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
	Reg#(Bit#(32)) someData <- mkReg(32'hDEADBEEF);

	//Requests
	Vector#(4, ROW_REQ) testReq = newVector();
	testReq[0] = ROW_REQ{ 	rowAddr: 23,
						  	numRows: 3,
							reqSrc: fromInteger(valueOf(SELECTION_BLK)),
							op: WRITE };
	testReq[1] = ROW_REQ{ 	rowAddr: 23,
						  	numRows: 3,
							reqSrc: fromInteger(valueOf(SELECTION_BLK)),
							op: READ };
	
	testReq[2] = ROW_REQ{ 	rowAddr: 20,
						  	numRows: 5,
							reqSrc: fromInteger(valueOf(DEDUP_BLK)),
							op: WRITE };
	testReq[3] = ROW_REQ{ 	rowAddr: 20,
						  	numRows: 5,
							reqSrc: fromInteger(valueOf(DEDUP_BLK)),
							op: READ };

	//send some requests
	let currReq = testReq[reqInd];
	rule sendReqs if (state==TEST_IDLE);
		$display("TB: sending req ind=%d", reqInd);

		marsh.rowAccesses[currReq.reqSrc].rowReq(currReq);
		if (currReq.op ==WRITE) begin
			state <= TEST_WR;
		end
		else begin
			state <= TEST_RD;
		end
	endrule

	rule burstingWR if (state==TEST_WR);
		$display("wburst [%d]: %x", brCount, someData);
		marsh.rowAccesses[currReq.reqSrc].writeData (someData);
		someData <= someData+1;
		if (brCount == currReq.numRows*32-1) begin
			brCount <= 0;
			state <= TEST_IDLE;
			reqInd <= reqInd+1;
			$display("TB: done sending bursts");
		end
		else begin
			brCount <= brCount+1;
		end
	endrule

	rule burstingRD if (state==TEST_RD);
		let rburst = marsh.rowAccesses[currReq.reqSrc].readResp;
		$display("rburst [%d]: %x", brCount, rburst);
		if (brCount == currReq.numRows*32-1) begin
			brCount <= 0;
			state <= TEST_IDLE;
			reqInd <= reqInd+1;
			$display("TB: done reading bursts");
		end
		else begin
			brCount <= brCount+1;
		end
	endrule
	
endmodule
