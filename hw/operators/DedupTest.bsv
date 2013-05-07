import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import ControllerTypes::*;
import RowMarshaller::*;
import Dedup::*;
import OperatorCommon::*;
import XilinxDDR2::*; 
import DDR2::*;


typedef enum { TEST_IDLE, TEST_REQ, TEST_WR, TEST_RD, TEST_DONE, TEST_PROJECT, TEST_WAIT, TEST_PRINT } TestState deriving (Eq, Bits);


//typedef 3 SEL_OP;
typedef 4 NUM_TESTS;
typedef 7 NUM_COLS;

module mkDedupTest();
   DDR2_User ddrServer <- mkDDR2Simulator();
   ROW_MARSHALLER_IFC marsh <- mkRowMarshaller();
   OPERATOR_IFC xprod <- mkDedup();
	
   //connect ddr and marshaller
   mkConnection(marsh.ddrMem, ddrServer);

   //connect marshaller to operator
   mkConnection(marsh.rowAccesses[valueOf(DEDUP_BLK)], xprod.rowIfc);

   //states
   Reg#(TestState) state <- mkReg(TEST_IDLE);
   Reg#(Bit#(31)) brCount <- mkReg(0);
   Reg#(Bit#(32)) reqInd <- mkReg(0);
   Reg#(Bit#(32)) printColCnt <- mkReg(0);
   Reg#(Bit#(32)) printRowCnt <- mkReg(0);
   
   Reg#(Bit#(32)) colCnt <- mkReg(0);
   Reg#(Bit#(32)) rowCnt <- mkReg(0);

   //data
   //Reg#(RowBurst) someData <- mkReg(32'hDEADBEEF);
   Reg#(RowBurst) someData <- mkReg('hDEADBEEF);

   //Requests
   Vector#(NUM_TESTS, RowReq) testReq = newVector();
   
   testReq[0] = RowReq{tableAddr: 23,
		       rowOffset: 0,
		       numRows: 20,
		       numCols: fromInteger(valueOf(NUM_COLS)), 
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       reqType: REQ_ALLROWS,
		       op: WRITE };
   /*
   testReq[1] = RowReq{tableAddr: 23,
		       rowOffset: 20,
		       numRows: 8,
		       numCols: fromInteger(valueOf(NUM_COLS)), 
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       reqType: REQ_EOT,
		       op: WRITE };
   */
   testReq[1] = RowReq{tableAddr: 10,
		       rowOffset: 0,
		       numRows: 1,
		       numCols: fromInteger(valueOf(NUM_COLS)),
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       reqType: REQ_ALLROWS,
		       op: WRITE };
   /*
   testReq[3] = RowReq{tableAddr: 10,
		       rowOffset: 1,
		       numRows: 8,
		       numCols: fromInteger(valueOf(NUM_COLS)),
		       reqType: REQ_EOT,
		       op: WRITE };
   */
   
   testReq[2] = RowReq{tableAddr: 23,
		       rowOffset: 0,
		       numRows: ?,
		       numCols: ?,
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       reqType: REQ_ALLROWS,
		       op: READ };
   
   testReq[3] = RowReq{tableAddr: 10,
		       rowOffset: 0,
		       numRows: ?,
		       numCols: ?,
		       reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
		       reqType: REQ_ALLROWS,
		       op: READ };
   

   //send some requests
   let currReq = testReq[reqInd];
   rule sendReqs if (state==TEST_IDLE);
      if (reqInd < fromInteger(valueOf(NUM_TESTS))) begin
	 $display(">>>>> TB: sending req ind=%d", reqInd);

	 marsh.rowAccesses[currReq.reqSrc].rowReq(currReq);
	 if (currReq.op==READ) begin
	    $display("going to read");
	    state <= TEST_RD;
	 end
	 else if (currReq.op==WRITE ) begin
	    state <= TEST_WR; 
	 end
      end
      else begin
	 //start PROJECTION block
	 state <= TEST_PROJECT;
      end
   endrule

   rule burstingWR if (state==TEST_WR);
      
      if (brCount == (currReq.numRows*currReq.numCols * fromInteger(valueOf(COLS_PER_BURST)))) begin
	 
	 marsh.rowAccesses[currReq.reqSrc].writeData (-1);
	 brCount <= 0;
	 state <= TEST_IDLE;
	 reqInd <= reqInd+1;
	 $display("TB: done sending bursts");
	 someData <= 'hDEADBEEF;
	 colCnt <= 0;
	 rowCnt <= 0;
	 
      end
      else begin
         $display("wburst [%d]: %x", brCount, someData);
	 marsh.rowAccesses[currReq.reqSrc].writeData (someData);
	 brCount <= brCount + 1;
	 if ( colCnt == fromInteger(valueOf(TSub#(NUM_COLS,1)))) begin
	     colCnt <= 0;
	     //rowCnt <= rowCnt + 1;
	     if ( rowCnt == 3 ) begin
		rowCnt <= 0;
		someData <= someData + 1;
	     end
	     else begin
		rowCnt <= rowCnt + 1;
	     end
	 end
	 else begin
	    colCnt <= colCnt + 1;
	 end
	 
	 
	 //someData <= someData+1;
	 //brCount <= brCount+1;
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
	     brCount <= 0;
	 end
	 else begin
	    brCount <= brCount+1;
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
			       op: DIFFERENCE,
			       table0Addr: 23,
			       //table0numRows: ?,
			       table0numCols: fromInteger(valueOf(NUM_COLS)), //just use max for now
			       //table1Addr: 10,
			       //table1numRows: 20,
			       //table1numCols: fromInteger(valueOf(NUM_COLS)),
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
      RowReq req = RowReq{tableAddr: 50,
			  rowOffset: 0,
			  numRows: ?,
			  numCols: 12,
			  reqSrc: fromInteger(valueOf(DATA_IO_BLK)),
			  reqType: REQ_NROWS,
			  op: READ };
      marsh.rowAccesses[valueOf(DATA_IO_BLK)].rowReq(req);
      state <= TEST_PRINT;
   endrule

   rule printResults if (state == TEST_PRINT);
      let rburst <- marsh.rowAccesses[valueOf(DATA_IO_BLK)].readResp;
      if (printColCnt == fromInteger(valueOf(TSub#(NUM_COLS,1)))) begin
	 printColCnt <= 0;
	 printRowCnt <= printRowCnt + 1;
      end
      else begin
	 printColCnt <= printColCnt + 1;
      end
      $display("rburst [%d][%d]: %x", printRowCnt,printColCnt, rburst);
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
