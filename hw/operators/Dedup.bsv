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

typedef enum {DEDUP_IDLE, DEDUP_CP_TABLE0_RD_REQ, DEDUP_OUTER_BUFF_ROW, DEDUP_PROCESS_ROW, DEDUP_CP_TABLE0_WR_REQ, DEDUP_CP_TABLE0_WR_ROW}  DedupState deriving (Eq,Bits);
				     

module mkDedup #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   Reg#(DedupState) state <- mkReg(DEDUP_IDLE);
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
	
   rule dedup_idle if (state == DEDUP_IDLE);
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
      state <= DEDUP_CP_TABLE0_RD_REQ;
   endrule
   
   rule outer_loop_rd_req if (state == DEDUP_CP_TABLE0_RD_REQ);
      //$display("DEDUP_CP_TABLE1_RD_REQ");
      if ( inputAddrCnt < currCmd.table0numRows ) begin
	 rowIfc.rowReq( RowReq{rowAddr: currCmd.table0Addr + inputAddrCnt,
			       numRows: 1,
			       reqSrc: fromInteger(valueOf(DEDUP_BLK)),
			       op: READ });
	 inputAddrCnt <= inputAddrCnt + 1;
	 state <= DEDUP_OUTER_BUFF_ROW;
      end
      else begin
	 cmdQ.deq();
	 ackRows.enq(outputAddrCnt);
	 state <= DEDUP_IDLE;
      end
   endrule
   
   rule outer_loop_rd_resp if (state == DEDUP_OUTER_BUFF_ROW);
      //$display("DEDUP_OUTER_BUFF_ROW");
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
	 rowIfc.rowReq( RowReq{rowAddr: currCmd.table0Addr + inputAddrCnt,
			       numRows: currCmd.table0numRows - inputAddrCnt,
			       reqSrc: fromInteger(valueOf(DEDUP_BLK)),
			       op: READ });
	 state <= DEDUP_PROCESS_ROW;
      end
   endrule
    
   rule process_row if (state == DEDUP_PROCESS_ROW);
      //$display("DEDUP_PROCESS_ROW");
      //$display(inner_rowCnt);
      //$display(inner_rdBurstCnt);
      //$display("match_found: %b", match_found);
      //$display("scan_rows: %b", scan_rows); 
      if ( inner_rowCnt < currCmd.table0numRows - inputAddrCnt ) begin
	 if ( inner_rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	    let rBurst <- rowIfc.readResp();
	    if ( scan_rows &&& rBurst != rowBuff[inner_rdBurstCnt] ) begin
	       //$display("mismatch found");
	       match_found <= False;
	    end	 
	    inner_rdBurstCnt <= inner_rdBurstCnt + 1;
	 end
	 else begin
	    inner_rdBurstCnt <= 0;
	    inner_rowCnt <= inner_rowCnt + 1;
	    match_found <= True;
	    if ( match_found == True ) begin
	       //$display("matching row found");
	       scan_rows <= False;
	    end
	 end
      end
      else begin
	 if ( scan_rows ) begin
	    //$display("no match found");
	    state <= DEDUP_CP_TABLE0_WR_REQ;
	 end
	 else begin
	    //$display("match found");
	    state <= DEDUP_CP_TABLE0_RD_REQ;
	 end
      end	  
   endrule
   
   rule cp_table1_wr_req if ( state == DEDUP_CP_TABLE0_WR_REQ);
      rowIfc.rowReq(RowReq{rowAddr: currCmd.outputAddr + outputAddrCnt,
			   numRows: 1,
			   reqSrc: fromInteger(valueOf(DEDUP_BLK)),
			   op: WRITE });
      outputAddrCnt <= outputAddrCnt + 1;
      state <= DEDUP_CP_TABLE0_WR_ROW;
   endrule
   
   rule cp_table1_wr_row if ( state == DEDUP_CP_TABLE0_WR_ROW );
      if ( wrBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW))) begin
	 rowIfc.writeData(rowBuff[wrBurstCnt]);
	 wrBurstCnt <= wrBurstCnt + 1;
      end
      else begin
	 wrBurstCnt <= 0;
	 state <= DEDUP_CP_TABLE0_RD_REQ;
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
