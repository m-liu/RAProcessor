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

typedef enum {DIFFERENCE_IDLE, DIFFERENCE_CP_TABLE0_RD_REQ, DIFFERENCE_OUTER_BUFF_ROW, DIFFERENCE_PROCESS_ROW, DIFFERENCE_CP_TABLE0_WR_REQ, DIFFERENCE_CP_TABLE0_WR_ROW}  DifferenceState deriving (Eq,Bits);
				     

module mkDifference #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   Reg#(DifferenceState) state <- mkReg(DIFFERENCE_IDLE);
   //Reg#(Row) ouputBuff <- mkReg(0);
   
   Vector#(BURSTS_PER_ROW, Reg#(RowBurst)) rowBuff <- replicateM(mkRegU());
   Reg#(RowAddr) inputAddrCnt <- mkReg(0);
   Reg#(RowAddr) outputAddrCnt <- mkReg(0);
   Reg#(RowAddr) outer_rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) inner_rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) wrBurstCnt <- mkReg(0);
   Reg#(RowAddr) table0ColCnt <- mkReg(0);
   Reg#(RowAddr) outer_rowCnt <- mkReg(0);
   Reg#(RowAddr) inner_rowCnt <- mkReg(0);
   Reg#(RowAddr) total_rowCnt <- mkReg(0);
   Reg#(Bool) match_found <- mkReg(True);
   Reg#(Bool) scan_rows <- mkReg(True);

   Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule diff_idle if (state == DIFFERENCE_IDLE);
      //$display("IDLE");
      inputAddrCnt <= 0;
      outputAddrCnt <= 0;
      outer_rdBurstCnt <= 0;
      inner_rdBurstCnt <= 0;
      wrBurstCnt <= 0;
      table0ColCnt <= 0;
      outer_rowCnt <= 0;
      inner_rowCnt <= 0;
      total_rowCnt <= 0;
      state <= DIFFERENCE_CP_TABLE0_RD_REQ;
   endrule
   
   rule outer_loop_rd_req if (state == DIFFERENCE_CP_TABLE0_RD_REQ);
      //$display("DIFFERENCE_CP_TABLE1_RD_REQ");
      if ( inputAddrCnt < currCmd.table0numRows ) begin
	 rowIfc.rowReq( RowReq{rowAddr: currCmd.table0Addr + inputAddrCnt,
			       numRows: 1,
			       reqSrc: fromInteger(valueOf(DIFFERENCE_BLK)),
			       op: READ });
	 inputAddrCnt <= inputAddrCnt + 1;
	 state <= DIFFERENCE_OUTER_BUFF_ROW;
      end
      else begin
	 cmdQ.deq();
	 ackRows.enq(outputAddrCnt);
	 state <= DIFFERENCE_IDLE;
      end
   endrule
   
   rule outer_loop_rd_resp if (state == DIFFERENCE_OUTER_BUFF_ROW);
      //$display("DIFFERENCE_OUTER_BUFF_ROW");
      if (outer_rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW))) begin
	 let rburst <- rowIfc.readResp();
	 rowBuff[outer_rdBurstCnt] <= rburst;
	 outer_rdBurstCnt <= outer_rdBurstCnt + 1;
      end
      else begin
	 outer_rdBurstCnt <= 0;
	 inner_rdBurstCnt <= 0;
	 inner_rowCnt <= 0;
	 match_found <= True;
	 scan_rows <= True;
	 rowIfc.rowReq( RowReq{rowAddr: currCmd.table1Addr,
			       numRows: currCmd.table1numRows,
			       reqSrc: fromInteger(valueOf(DIFFERENCE_BLK)),
			       op: READ });
	 state <= DIFFERENCE_PROCESS_ROW;
      end
   endrule
    
   rule process_row if (state == DIFFERENCE_PROCESS_ROW);
      $display("DIFFERENCE_PROCESS_ROW");
      $display(inner_rowCnt);
      //$display(inner_rdBurstCnt);
      //$display("match_found: %b", match_found);
      //$display("scan_rows: %b", scan_rows); 
      if ( inner_rowCnt < currCmd.table1numRows ) begin
	 if ( inner_rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	    let rBurst <- rowIfc.readResp();
	    $display("table 0 data %d", rowBuff[inner_rdBurstCnt]);
	    $display("table 1 data %d", rBurst);
	    if ( scan_rows &&& rBurst != rowBuff[inner_rdBurstCnt] ) begin
	       $display("mismatch found");
	       match_found <= False;
	    end	 
	    inner_rdBurstCnt <= inner_rdBurstCnt + 1;
	 end
	 else begin
	    inner_rdBurstCnt <= 0;
	    inner_rowCnt <= inner_rowCnt + 1;
	    match_found <= True;
	    if ( match_found == True ) begin
	       $display("matching row found");
	       scan_rows <= False;
	    end
	 end
      end
      else begin
	 if ( scan_rows ) begin
	    $display("no match found");
	    state <= DIFFERENCE_CP_TABLE0_WR_REQ;
	 end
	 else begin
	    $display("match found");
	    state <= DIFFERENCE_CP_TABLE0_RD_REQ;
	 end
      end	  
   endrule
   
   rule cp_table1_wr_req if ( state == DIFFERENCE_CP_TABLE0_WR_REQ);
      rowIfc.rowReq(RowReq{rowAddr: currCmd.outputAddr + outputAddrCnt,
			   numRows: 1,
			   reqSrc: fromInteger(valueOf(DIFFERENCE_BLK)),
			   op: WRITE });
      outputAddrCnt <= outputAddrCnt + 1;
      state <= DIFFERENCE_CP_TABLE0_WR_ROW;
   endrule
   
   rule cp_table1_wr_row if ( state == DIFFERENCE_CP_TABLE0_WR_ROW );
      if ( wrBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW))) begin
	 rowIfc.writeData(rowBuff[wrBurstCnt]);
	 wrBurstCnt <= wrBurstCnt + 1;
      end
      else begin
	 wrBurstCnt <= 0;
	 state <= DIFFERENCE_CP_TABLE0_RD_REQ;
      end
   endrule
   
	 
   


   //interface definition
   method Action pushCommand (CmdEntry cmdEntry);
      cmdQ.enq(cmdEntry);
   endmethod

   method ActionValue#( Bit#(31) ) getAckRows();
      ackRows.deq();
      return ackRows.first();
   endmethod

endmodule
