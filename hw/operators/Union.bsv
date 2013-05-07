//union operator
import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import OperatorCommon::*;
import RowMarshaller::*;
import ControllerTypes::*;

typedef enum {UNION_IDLE, UNION_CP_TABLE0_WR, UNION_CP_TABLE0, UNION_CP_TABLE1_RD_REQ, UNION_OUTER_BUFF_ROW, UNION_PROCESS_ROW, UNION_CP_TABLE1_WR_REQ, UNION_CP_TABLE1_WR_ROW}  UnionState deriving (Eq,Bits);
				     

//module mkUnion #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);
(* synthesize *)
module mkUnion (OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   FIFO#(RowReq) rowReqQ <- mkFIFO;
   FIFO#(RowBurst) wdataQ <- mkFIFO;
   FIFO#(RowBurst) rdataQ <- mkFIFO;
   Reg#(UnionState) state <- mkReg(UNION_IDLE);
   //Reg#(Row) ouputBuff <- mkReg(0);
   
   Vector#(BURSTS_PER_ROW, Reg#(RowBurst)) rowBuff <- replicateM(mkRegU());
   Reg#(RowAddr) inputAddrCnt <- mkReg(0);
   Reg#(RowAddr) outputAddrCnt_Col <- mkReg(0);
   Reg#(RowAddr) outputAddrCnt <- mkReg(0);
   Reg#(RowAddr) outer_rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) inner_rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) wrBurstCnt <- mkReg(0);
   //Reg#(RowAddr) table0ColCnt <- mkReg(0);
   //Reg#(RowAddr) outer_rowCnt <- mkReg(0);
   //Reg#(RowAddr) inner_rowCnt <- mkReg(0);
   //Reg#(RowAddr) total_rowCnt <- mkReg(0);
   Reg#(Bool) match_found <- mkReg(True);
   Reg#(Bool) scan_rows <- mkReg(True);
   

  // Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule union_idle if (state == UNION_IDLE);
      //$display("IDLE");
      inputAddrCnt <= 0;
      outputAddrCnt_Col <= 0;
      outputAddrCnt <= 0;
      outer_rdBurstCnt <= 0;
      inner_rdBurstCnt <= 0;
      wrBurstCnt <= 0;
      //table0ColCnt <= 0;
     // outer_rowCnt <= 0;
      //inner_rowCnt <= 0;
      //total_rowCnt <= 0;
      state <= UNION_CP_TABLE0_WR;
      rowReqQ.enq(RowReq{tableAddr: currCmd.table0Addr,
			 rowOffset: 0,
			 numRows: ?,
			 numCols: ?,
			 reqSrc: fromInteger(valueOf(UNION_BLK)),
			 reqType: REQ_ALLROWS,
			 op: READ });
   endrule
   
   rule cp_table0_wr if ( state == UNION_CP_TABLE0_WR);
      //$display("UNION_CP_TABLE0_WR_REQ");
      rowReqQ.enq(RowReq{tableAddr: currCmd.outputAddr,
			 rowOffset: 0,
			 numRows: ?,
			 numCols: ?,
			 reqSrc: fromInteger(valueOf(UNION_BLK)),
			 reqType: REQ_ALLROWS,
			 op: WRITE });
      state <= UNION_CP_TABLE0;
   endrule
   
   rule cp_table0 if (state == UNION_CP_TABLE0);
      let rBurst = rdataQ.first();
      rdataQ.deq();
      
      if ( reduceAnd(rBurst) == 1 ) begin
	 state <= UNION_CP_TABLE1_RD_REQ;
      end
      else begin
	 if ( outputAddrCnt_Col < currCmd.table0numCols - 1 ) begin
	    outputAddrCnt_Col <= outputAddrCnt_Col + 1;
	 end
	 else begin
	    outputAddrCnt_Col <= 0;
	    outputAddrCnt <= outputAddrCnt + 1;
	 end
	 wdataQ.enq(rBurst);
      end
      
      
      
      //$display("UNION_CP_TABLE0");
      //$display(outer_rowCnt);
      //$display(outer_rdBurstCnt);
      /*
      if ( outer_rowCnt < currCmd.table0numRows ) begin
	 if ( outer_rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW))) begin
	    let rburst = rdataQ.first();
		rdataQ.deq();
	    wdataQ.enq(rburst);
	    outer_rdBurstCnt <= outer_rdBurstCnt + 1;
	 end
	 else begin
	    outer_rdBurstCnt <= 0;
	    outer_rowCnt <= outer_rowCnt + 1;
	 end
      end
      else begin
	 outer_rowCnt <= 0;
	 state <= UNION_CP_TABLE1_RD_REQ;
	 //$display("exiting");
      end
      */
   endrule
   
   
   rule outer_loop_rd_req if (state == UNION_CP_TABLE1_RD_REQ);
      //$display("UNION_CP_TABLE1_RD_REQ");
      rowReqQ.enq( RowReq{tableAddr: currCmd.table1Addr,
			  rowOffset: inputAddrCnt,
			  numRows: 1,
			  numCols: currCmd.table1numCols,
			  reqSrc: fromInteger(valueOf(UNION_BLK)),
			  reqType: REQ_NROWS,
			  op: READ });
      inputAddrCnt <= inputAddrCnt + 1;
      state <= UNION_OUTER_BUFF_ROW;
      
   endrule
   
   rule outer_loop_rd_resp if (state == UNION_OUTER_BUFF_ROW);
      $display("UNION_OUTER_BUFF_ROW");
      $display("inputAddrCnt: %d", inputAddrCnt);
      if (outer_rdBurstCnt < currCmd.table1numCols) begin
	 let rburst = rdataQ.first();
	 $display("rburst = %h",rburst);
	 rdataQ.deq();
	 rowBuff[outer_rdBurstCnt] <= rburst;
	 
	 outer_rdBurstCnt <= outer_rdBurstCnt + 1;
      end
      else begin
	 if ( reduceAnd(rowBuff[0]) == 1 ) begin
	    cmdQ.deq();
	    ackRows.enq(outputAddrCnt);
	    state <= UNION_IDLE;
	    wdataQ.enq(-1);
	    /*
	    rowReqQ.enq(RowReq{tableAddr: currCmd.outputAddr,
			 rowOffset: outputAddrCnt,
			 numRows: 8,
			 numCols: currCmd.table0numCols,
			 reqSrc: fromInteger(valueOf(UNION_BLK)),
			 reqType: REQ_EOT,
			 op: WRITE });
	     */
	 end
	 else begin
	    outer_rdBurstCnt <= 0;
	    inner_rdBurstCnt <= 0;
	    //inner_rowCnt <= 0;
	    match_found <= True;
	    scan_rows <= True;
	    rowReqQ.enq( RowReq{tableAddr: currCmd.table0Addr,
				rowOffset: 0,
				numRows: ?,
				numCols: ?,
				reqSrc: fromInteger(valueOf(UNION_BLK)),
				reqType: REQ_ALLROWS,
				op: READ });
	    state <= UNION_PROCESS_ROW;
	 end
      end
   endrule
    
   rule process_row if (state == UNION_PROCESS_ROW);
      $display("UNION_PROCESS_ROW");
      //$display(inner_rowCnt);
      //$display(inner_rdBurstCnt);
      //$display("match_found: %b", match_found);
      //$display("scan_rows: %b", scan_rows);
      
      if ( inner_rdBurstCnt < currCmd.table0numCols ) begin
	 let rBurst = rdataQ.first();
	 rdataQ.deq();
	 $display("rBurst = %h", rBurst);
	 
	 if ( scan_rows &&& rBurst != rowBuff[inner_rdBurstCnt] ) begin
	    $display("mismatch found");
	    match_found <= False;
	 end	 
	 inner_rdBurstCnt <= inner_rdBurstCnt + 1;
      end
      else begin
	 let rBurst = rdataQ.first();
	 if ( match_found == True ) begin
	    $display("matching row found");
	    scan_rows <= False;
	    match_found <= False;
	 end
	 else begin
	    if ( reduceAnd(rBurst) == 1 ) begin
	       rdataQ.deq();
	       if ( scan_rows ) begin
		  $display("no match found");
		  state <= UNION_CP_TABLE1_WR_ROW;
		  outputAddrCnt <= outputAddrCnt + 1;
	       end
	       else begin
		  $display("match found");
		  state <= UNION_CP_TABLE1_RD_REQ;
	       end
	    end
	    else begin   
	       match_found <= True;
	       inner_rdBurstCnt <= 0;
	       //inner_rowCnt <= inner_rowCnt + 1;      
	    end
	 end
      end
      
   endrule
   /*
   rule cp_table1_wr_req if ( state == UNION_CP_TABLE1_WR_REQ);
      rowReqQ.enq(RowReq{tableAddr: currCmd.outputAddr,
			 rowOffset: outputAddrCnt,
			 numRows: 1,
			 numCols: currCmd.table0numCols,
			 reqSrc: fromInteger(valueOf(UNION_BLK)),
			 reqType: REQ_NROWS,
			 op: WRITE });
      outputAddrCnt <= outputAddrCnt + 1;
      state <= UNION_CP_TABLE1_WR_ROW;
   endrule
   */
   rule cp_table1_wr_row if ( state == UNION_CP_TABLE1_WR_ROW );
      if ( wrBurstCnt < currCmd.table0numCols ) begin
	 wdataQ.enq(rowBuff[wrBurstCnt]);
	 wrBurstCnt <= wrBurstCnt + 1;
      end
      else begin
	 wrBurstCnt <= 0;
	 state <= UNION_CP_TABLE1_RD_REQ;
      end
   endrule
   
	 
   

	//Interface definitions. 
	interface ROW_ACCESS_CLIENT_IFC rowIfc;
		method ActionValue#(RowReq) rowReq();
			rowReqQ.deq();
			return rowReqQ.first();
		endmethod
		method Action readResp (RowBurst rData);
			rdataQ.enq(rData);
		endmethod
		method ActionValue#(RowBurst) writeData();
			wdataQ.deq();
			return wdataQ.first();
		endmethod
	endinterface 

	interface CMD_SERVER_IFC cmdIfc; 

		//interface definition
		method Action pushCommand (CmdEntry cmdEntry);
			cmdQ.enq(cmdEntry);
		endmethod

		method ActionValue#( Bit#(31) ) getAckRows();
			ackRows.deq();
			return ackRows.first();
		endmethod
	endinterface



endmodule
