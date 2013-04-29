//xprod operator
import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import OperatorCommon::*;
import RowMarshaller::*;
import ControllerTypes::*;

typedef enum {XPROD_IDLE, XPROD_OUTER_RD_REQ, XPROD_OUTER_BUFF_ROW, XPROD_INNER_WR_REQ, XPROD_PROCESS_ROW} XProdState deriving (Eq,Bits);
				     

//module mkXprod #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);
module mkXprod (OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   FIFO#(RowReq) rowReqQ <- mkFIFO;
   FIFO#(RowBurst) wdataQ <- mkFIFO;
   FIFO#(RowBurst) rdataQ <- mkFIFO;
   Reg#(XProdState) state <- mkReg(XPROD_IDLE);
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

   Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule xprod_idle if (state == XPROD_IDLE);
      $display("IDLE");
      inputAddrCnt <= 0;
      outputAddrCnt <= 0;
      outer_rdBurstCnt <= 0;
      inner_rdBurstCnt <= 0;
      wrBurstCnt <= 0;
      table0ColCnt <= 0;
      outer_rowCnt <= 0;
      inner_rowCnt <= 0;
      total_rowCnt <= 0;
      state <= XPROD_OUTER_RD_REQ;
   endrule
   
   rule outer_loop_rd_req if (state == XPROD_OUTER_RD_REQ);
      $display("OUTER_RD_REQ");
      $display(showCmd(currCmd));
      rowReqQ.enq( RowReq{rowAddr: currCmd.table0Addr + inputAddrCnt,
			    numRows: 1,
			    reqSrc: fromInteger(valueOf(XPROD_BLK)),
			    op: READ });
      inputAddrCnt <= inputAddrCnt + 1;
      state <= XPROD_OUTER_BUFF_ROW;
   endrule
   
   rule outer_loop_rd_resp if (state == XPROD_OUTER_BUFF_ROW);
      $display("OUTER_RD_RESP");
      if (outer_rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW))) begin
	 let rburst = rdataQ.first();
	 rdataQ.deq(); 
	 rowBuff[outer_rdBurstCnt] <= rburst;
	 
	 $display("%h",rburst);
	 
	 /*
	 //Right shifts in the bursts
	 rowBuff <= {rburst, (rowBuff >> valueOf(BURST_WIDTH))[ROW_BITS - BURSTWIDTH - 1:0]};
	  */
	 outer_rdBurstCnt <= outer_rdBurstCnt + 1;
      end
      else begin
	 outer_rdBurstCnt <= 0;
	 rowReqQ.enq( RowReq{rowAddr: currCmd.table1Addr,
			       numRows: currCmd.table1numRows,
			       reqSrc: fromInteger(valueOf(XPROD_BLK)),
			       op: READ });
	 state <= XPROD_INNER_WR_REQ;
	
      end
   endrule
   
   
   rule inner_loop_wr_req if (state == XPROD_INNER_WR_REQ);
      $display("INNER_WR_REQ");
      rowReqQ.enq( RowReq{rowAddr: currCmd.outputAddr+outputAddrCnt,
			    numRows: currCmd.table1numRows,
			    reqSrc: fromInteger(valueOf(XPROD_BLK)),
			    op: WRITE });
      state <= XPROD_PROCESS_ROW;
      wrBurstCnt <= currCmd.table0numCols;
      inner_rdBurstCnt <= 0;
   endrule
   
   rule process_row if (state == XPROD_PROCESS_ROW);
      $display("PROCESS_ROW");
      $display(wrBurstCnt);
      // stream in the cols in the table0row
      if ( table0ColCnt < currCmd.table0numCols ) begin
	 $display("stream in the cols in the table0row: %h", rowBuff[table0ColCnt]);
	 wdataQ.enq(rowBuff[table0ColCnt]);
	 table0ColCnt <= table0ColCnt + 1;
      end
      else begin
	 // stream in the cols in the table1row
	 if ( inner_rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	    let rBurst = rdataQ.first();
		rdataQ.deq(); 
	    inner_rdBurstCnt <= inner_rdBurstCnt + 1;
	    if ( wrBurstCnt < currCmd.table0numCols + currCmd.table1numCols ) begin
	       $display("stream in the cols in the table1row %h", rBurst);
	       wdataQ.enq(rBurst);
	       wrBurstCnt <= wrBurstCnt + 1;
	    end
	    else
	       $display("draining 0s");
	 end
	 else begin
	    // stream in the appending 0s
	    if ( wrBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	       $display("appending 0s");
	       wdataQ.enq(0);
	       wrBurstCnt <= wrBurstCnt + 1;
	    end
	    else begin
	       $display("one row finishes");
	       table0ColCnt <= 0;
	       inner_rdBurstCnt <= 0;
	       wrBurstCnt <= currCmd.table0numCols;
	       total_rowCnt <= total_rowCnt + 1;
	       // if inner loop finishes
	       if ( inner_rowCnt + 1 >= currCmd.table1numRows ) begin
		  $display("inner loop finishes");
		  inner_rowCnt <= 0;
		  outer_rowCnt <= outer_rowCnt + 1;
		  // if outer loop finishes
		  if ( outer_rowCnt + 1 >= currCmd.table0numRows ) begin
		     $display("outer loop finishes");
		     cmdQ.deq();
		     ackRows.enq(total_rowCnt + 1);
		     state <= XPROD_IDLE;
		  end
		  else begin
		     outputAddrCnt <= outputAddrCnt + currCmd.table1numRows;
		     state <= XPROD_OUTER_RD_REQ;
		  end
	       end
	       
	       else begin
		  inner_rowCnt <= inner_rowCnt + 1;
	       end
	       
	    end
	 end
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
