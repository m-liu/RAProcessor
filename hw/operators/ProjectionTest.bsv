import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import ControllerTypes::*;
import RowMarshaller::*;
import Projection::*;
import OperatorCommon::*;
import XilinxDDR2::*; 
import DDR2::*;


typedef enum { TEST_IDLE, TEST_REQ, TEST_WR, TEST_RD, TEST_DONE, TEST_PROJECT, TEST_WAIT, TEST_PRINT } TestState deriving (Eq, Bits);


//typedef 3 SEL_OP;
typedef 3 NUM_TESTS;

module mkProjectionTest();
   DDR2_User ddrServer <- mkDDR2Simulator();
   ROW_MARSHALLER_IFC marsh <- mkRowMarshaller();
   OPERATOR_IFC projection <- mkProjection();
	
   //connect ddr and marshaller
   mkConnection(marsh.ddrMem, ddrServer);

	//connect marshaller to operator
	mkConnection(marsh.rowAccesses[valueOf(PROJECTION_BLK)], projection.rowIfc);


   //states
   Reg#(TestState) state <- mkReg(TEST_IDLE);
   Reg#(Bit#(31)) brCount <- mkReg(0);
   Reg#(Bit#(32)) reqInd <- mkReg(0);
	Reg#(Bit#(32)) printColCnt <- mkReg(0);
	Reg#(Bit#(32)) printRowCnt <- mkReg(0);

   //data
   //Reg#(RowBurst) someData <- mkReg(32'hDEADBEEF);
   Reg#(RowBurst) someData <- mkReg('hDEADBEEF);

   //Requests
   Vector#(NUM_TESTS, RowReq) testReq = newVector();
	testReq[0] = RowReq{ 	tableAddr: 23,
							rowOffset: 0,
						  	numRows: 20,
							numCols: 7, 
							reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
							reqType: REQ_NROWS,
							op: WRITE };
	
	testReq[1] = RowReq{ 	tableAddr: 23,
							rowOffset: 20,
						  	numRows: 8,
							numCols: 7, 
							reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
							reqType: REQ_EOT,
							op: WRITE };

	testReq[2] = RowReq{ 	tableAddr: 23,
							rowOffset: 0,
						  	numRows: ?,
							numCols: 7,
							reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
							reqType: REQ_ALLROWS,
							op: READ };

   //send some requests
   let currReq = testReq[reqInd];
   rule sendReqs if (state==TEST_IDLE);
	   if (reqInd < fromInteger(valueOf(NUM_TESTS))) begin

		   $display("TB: sending req ind=%d", reqInd);

		   marsh.rowAccesses[currReq.reqSrc].rowReq(currReq);
		   if (currReq.op ==WRITE) begin
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
		   //start PROJECTION block
		   state <= TEST_PROJECT;
	   end
   endrule

   rule burstingWR if (state==TEST_WR);
	   $display("wburst [%d]: %x", brCount, someData);
	   marsh.rowAccesses[currReq.reqSrc].writeData (someData);
	   someData <= someData+1;
	   if (brCount == (currReq.numRows*currReq.numCols * fromInteger(valueOf(COLS_PER_BURST)))-1) begin
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
	   let rburst <- marsh.rowAccesses[currReq.reqSrc].readResp;
	   $display("rburst [%d]: %x", brCount, rburst);
	   let totalBursts = currReq.numRows * currReq.numCols * fromInteger(valueOf(COLS_PER_BURST));


		if (currReq.reqType == REQ_ALLROWS) begin
			if (reduceAnd(rburst) == 1) begin
			//if (brCount == currReq.numRows*32-1) begin
				state <= TEST_IDLE;
				reqInd <= reqInd+1;
				$display("TB AR: done reading bursts");
			end
		end
		else begin
			if (brCount == totalBursts-1) begin
			//if (brCount == currReq.numRows*32-1) begin
				brCount <= 0;
				state <= TEST_IDLE;
				reqInd <= reqInd+1;
				$display("TB: done reading bursts");
			end
			else begin
				brCount <= brCount+1;
			end
		end

   endrule
	

   rule testProject if (state==TEST_PROJECT);
	  $display("\n\n ***** STARTING PROJECTION TEST ****** \n");
      CmdEntry cmd = CmdEntry {
			       op: PROJECT,
			       table0Addr: 23,
			       table0numRows: 0, //should not be used
			       table0numCols: 7, //just use max for now
			       outputAddr: 50,
			       colProjectMask: 'h13,
				   projColNum: 3
			       //clauses: testClauses,
			       //validClauseMask: 'h11 //OR
						};
      projection.cmdIfc.pushCommand(cmd);	
      state <= TEST_WAIT;
   endrule

   rule waitSelect if (state == TEST_WAIT);
      let respRows <- projection.cmdIfc.getAckRows();
      $display("Proj done. Num rows = %d", respRows);
      //make req to print results
      RowReq req = RowReq{
				  tableAddr: 50,
				  rowOffset: 0,
				  numRows: ?,
				  numCols: 3,
				  reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
				  reqType: REQ_ALLROWS,
				  op: READ };
      marsh.rowAccesses[valueOf(DATA_IO_BLK)].rowReq(req);
      state <= TEST_PRINT;
   endrule

   rule printResults if (state == TEST_PRINT);
		let rburst <- marsh.rowAccesses[valueOf(DATA_IO_BLK)].readResp;
		if (printColCnt == 2) begin
			printColCnt <= 0;
			printRowCnt <= printRowCnt+1;
		end
		else begin
			printColCnt <= printColCnt + 1;
		end
		$display("rburst row[%d] col[%d]: %x", printRowCnt, printColCnt, rburst);
		//if (brCount == (20*fromInteger(valueOf(BURSTS_PER_ROW)))-1) begin
		//if (brCount == currReq.numRows*32-1) begin
		if (reduceAnd(rburst) == 1) begin
			//brCount <= 0;
			state <= TEST_IDLE;
			$display("TB: done reading bursts");
			$finish;
		end
   endrule

endmodule
