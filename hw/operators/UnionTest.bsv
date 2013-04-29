import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import ControllerTypes::*;
import RowMarshaller::*;
import Union::*;
import OperatorCommon::*;
import XilinxDDR2::*; 
import DDR2::*;


typedef enum { TEST_IDLE, TEST_REQ, TEST_WR, TEST_RD, TEST_DONE, TEST_PROJECT, TEST_WAIT, TEST_PRINT } TestState deriving (Eq, Bits);


//typedef 3 SEL_OP;
typedef 4 NUM_TESTS;

module mkUnionTest();
   DDR2_User ddrServer <- mkDDR2Simulator();
   ROW_MARSHALLER_IFC marsh <- mkRowMarshaller();
   OPERATOR_IFC xprod <- mkUnion();
	
   //connect ddr and marshaller
   mkConnection(marsh.ddrMem, ddrServer);

   //connect marshaller to operator
   mkConnection(marsh.rowAccesses[valueOf(UNION_BLK)], xprod.rowIfc);

   //states
   Reg#(TestState) state <- mkReg(TEST_IDLE);
   Reg#(Bit#(31)) brCount <- mkReg(0);
   Reg#(Bit#(32)) reqInd <- mkReg(0);

   //data
   //Reg#(RowBurst) someData <- mkReg(32'hDEADBEEF);
   Reg#(RowBurst) someData <- mkReg('hDEADBEEF);

   //Requests
   Vector#(NUM_TESTS, RowReq) testReq = newVector();
   testReq[0] = RowReq{rowAddr: 23,
		       numRows: 20,
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       op: WRITE };
   testReq[1] = RowReq{rowAddr: 23,
		       numRows: 20,
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       op: READ };
	
   testReq[2] = RowReq{rowAddr: 10,
		       numRows: 5,
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       op: WRITE };
   testReq[3] = RowReq{rowAddr: 10,
		       numRows: 5,
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
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
	 else begin
	    state <= TEST_RD;
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
      if (brCount == (currReq.numRows*fromInteger(valueOf(BURSTS_PER_ROW)))-1) begin
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
      if (brCount == (currReq.numRows*fromInteger(valueOf(BURSTS_PER_ROW)))-1) begin
	 //if (brCount == currReq.numRows*32-1) begin
	 brCount <= 0;
	 state <= TEST_IDLE;
	 reqInd <= reqInd+1;
	 $display("TB: done reading bursts");
      end
      else begin
	 brCount <= brCount+1;
      end
   endrule
	

   rule testProject if (state==TEST_PROJECT);
      /*
      Vector#(MAX_CLAUSES, SelClause) testClauses = newVector();

      //col [1] > DEADBEFF
      testClauses[0] = SelClause{ 
				 clauseType: COL_VAL,
				 colOffset0: 4,
				 colOffset1: 0,
				 op: GT,
				 val: 'hDEADBEFF };

      //OR col [4] < col [0] (never true)
      testClauses[4] = SelClause{ 
				 clauseType: COL_COL,
				 colOffset0: 4,
				 colOffset1: 5,
				 op: GT,
				 val: 'hDEADFFFF };

      */
      $display("Sending cmd to testing block");
      CmdEntry cmd = CmdEntry {
			       op: UNION,
			       table0Addr: 23,
			       table0numRows: 4,
			       table0numCols: 32, //just use max for now
			       table1Addr: 25,
			       table1numRows: 2,
			       table1numCols: 32,
			       outputAddr: 50
			       //colProjectMask: 'h1111
			       //clauses: testClauses,
			       //validClauseMask: 'h11 //OR
						};
      xprod.cmdIfc.pushCommand(cmd);	
      state <= TEST_WAIT;
   endrule

   rule waitSelect if (state == TEST_WAIT);
      let respRows <- xprod.cmdIfc.getAckRows();
      $display("Select done. Num rows = %d", respRows);
      //make req to print results
      RowReq req = RowReq{rowAddr: 50,
			  numRows: 4,
			  reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
			  op: READ };
      marsh.rowAccesses[valueOf(DATA_IO_BLK)].rowReq(req);
      state <= TEST_PRINT;
   endrule

   rule printResults if (state == TEST_PRINT);
      let rburst = marsh.rowAccesses[valueOf(DATA_IO_BLK)].readResp;
      $display("rburst [%d]: %x", brCount, rburst);
      if (brCount == (4*fromInteger(valueOf(BURSTS_PER_ROW)))-1) begin
	 //if (brCount == currReq.numRows*32-1) begin
	 brCount <= 0;
	 state <= TEST_IDLE;
	 $display("TB: done reading bursts");
	 $finish;
      end
      else begin
	 brCount <= brCount+1;
      end	
   endrule

endmodule
