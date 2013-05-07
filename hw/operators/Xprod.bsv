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
(* synthesize *)
module mkXprod (OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   FIFO#(RowReq) rowReqQ <- mkFIFO;
   FIFO#(RowBurst) wdataQ <- mkFIFO;
   FIFO#(RowBurst) rdataQ <- mkFIFO;
   Reg#(XProdState) state <- mkReg(XPROD_IDLE);
   //Reg#(Row) ouputBuff <- mkReg(0);
   
   Vector#(BURSTS_PER_ROW, Reg#(RowBurst)) rowBuff <- replicateM(mkRegU());
   //Reg#(Row) rowBuff <- mkReg(0);
   Reg#(RowAddr) inputAddrCnt <- mkReg(0);
   //Reg#(RowAddr) outputAddrCnt <- mkReg(0);
   Reg#(RowAddr) outer_rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) inner_rdBurstCnt <- mkReg(0);
   //Reg#(RowAddr) wrBurstCnt <- mkReg(0);
   Reg#(RowAddr) table0ColCnt <- mkReg(0);
   //Reg#(RowAddr) outer_rowCnt <- mkReg(0);
   //Reg#(RowAddr) inner_rowCnt <- mkReg(0);
   Reg#(RowAddr) total_rowCnt <- mkReg(0);

  // Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
   //Reg#(RowBurst) temp <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule xprod_idle if (state == XPROD_IDLE);
      $display("IDLE");
      inputAddrCnt <= 0;
      //outputAddrCnt <= 0;
      outer_rdBurstCnt <= 0;
      inner_rdBurstCnt <= 0;
      //wrBurstCnt <= 0;
      table0ColCnt <= 0;
      //outer_rowCnt <= 0;
      //inner_rowCnt <= 0;
      total_rowCnt <= 0;
      rowReqQ.enq( RowReq{tableAddr: currCmd.outputAddr,
			  rowOffset: 0,
			  numRows: ?,
			  numCols: ?,
			  reqSrc: fromInteger(valueOf(XPROD_BLK)),
			  reqType: REQ_ALLROWS,
			  op: WRITE });
      state <= XPROD_OUTER_RD_REQ;
   endrule
   
   rule outer_loop_rd_req if (state == XPROD_OUTER_RD_REQ);
      $display("OUTER_RD_REQ");
      //$display(showCmd(currCmd));
      rowReqQ.enq( RowReq{tableAddr: currCmd.table0Addr,
			  rowOffset: inputAddrCnt,
			  numRows: 1,
			  numCols: currCmd.table0numCols,
			  reqSrc: fromInteger(valueOf(XPROD_BLK)),
			  reqType: REQ_NROWS,
			  op: READ });
      inputAddrCnt <= inputAddrCnt + 1;
      //rowBuff <= 0;
      state <= XPROD_OUTER_BUFF_ROW;
   endrule
   
   rule outer_loop_rd_resp if (state == XPROD_OUTER_BUFF_ROW);
      $display("OUTER_RD_RESP");
      // currCmd.table0numCols + 1 is for 64-bit implementation in the future
      if (outer_rdBurstCnt < (currCmd.table0numCols)/fromInteger(valueOf(COLS_PER_BURST)) ) begin
	 let rburst = rdataQ.first();
	 rdataQ.deq(); 
	 rowBuff[outer_rdBurstCnt] <= rburst;
	 //rowBuff <= (rowBuff << valueOf(BURST_WIDTH)) | zeroExtended(rburst);
	 
	 $display("%h",rburst);
	 
	 /*
	 //Right shifts in the bursts
	 rowBuff <= {rburst, (rowBuff >> valueOf(BURST_WIDTH))[ROW_BITS - BURSTWIDTH - 1:0]};
	  */
	 outer_rdBurstCnt <= outer_rdBurstCnt + 1;
      end
      else begin
	 outer_rdBurstCnt <= 0;
	 
	 if ( reduceAnd(rowBuff[0]) == 1) begin
	    /*rowReqQ.enq( RowReq{tableAddr: currCmd.outputAddr,
				rowOffset: total_rowCnt,
				numRows: 8,
				numCols: currCmd.table0numCols + currCmd.table1numCols,
				reqSrc: fromInteger(valueOf(XPROD_BLK)),
				reqType: REQ_EOT,
				op: WRITE });
	    */
	    wdataQ.enq(-1);
	    $display("outer loop finishes");
	    cmdQ.deq();
	    ackRows.enq(total_rowCnt);
	    state <= XPROD_IDLE;
	 end
	 //RowAddr shiftVal = fromInteger(valueOf(BURSTS_PER_ROW)) - outer_rdBurstCnt;
	 //Row shiftedRow = rowBuff << (shiftVal * fromInteger(valueOf(BURST_WIDTH)));
	 else begin
	    rowReqQ.enq( RowReq{tableAddr: currCmd.table1Addr,
				rowOffset: 0,
				numRows: ?,
				numCols: ?,
				reqSrc: fromInteger(valueOf(XPROD_BLK)),
				reqType: REQ_ALLROWS,
				op: READ });
	    inner_rdBurstCnt <= 0;
	    state <= XPROD_PROCESS_ROW;
	 end
	
      end
   endrule
   
   /*
   rule inner_loop_wr_req if (state == XPROD_INNER_WR_REQ);
      $display("INNER_WR_REQ");
      rowReqQ.enq( RowReq{tableAddr: currCmd.outputAddr,
			  rowOffset: outputAddrCnt,
			  numRows: ?,
			  numCols: ?,
			  reqSrc: fromInteger(valueOf(XPROD_BLK)),
			  reqType: REQ_ALLROWS,
			  op: WRITE });
      state <= XPROD_PROCESS_ROW;
      //wrBurstCnt <= currCmd.table0numCols;
      inner_rdBurstCnt <= 0;
   endrule
    */
   
   rule process_row if (state == XPROD_PROCESS_ROW);
      $display("PROCESS_ROW");
      if ( table0ColCnt < (currCmd.table0numCols)/fromInteger(valueOf(COLS_PER_BURST)) ) begin
	       
	 
	 $display("outer_rd[%d] = %h",table0ColCnt,rowBuff[table0ColCnt]);
	 wdataQ.enq(rowBuff[table0ColCnt]);
	 table0ColCnt <= table0ColCnt + 1;
      end
      else begin
	 if ( inner_rdBurstCnt < currCmd.table1numCols ) begin
	    let rBurst = rdataQ.first();
	    rdataQ.deq(); 
	    $display("rdBurst[%d] = %h",inner_rdBurstCnt,rBurst);
	    inner_rdBurstCnt <= inner_rdBurstCnt + 1;
	    wdataQ.enq(rBurst);
	 end
	 else begin
	    let rBurst = rdataQ.first();
	    table0ColCnt <= 0;
	    inner_rdBurstCnt <= 0;
	    $display("total_row: %d",total_rowCnt);
	    total_rowCnt <= total_rowCnt + 1;
	    if ( reduceAnd(rBurst) == 1 ) begin
	       rdataQ.deq();
	       //outputAddrCnt <= outputAddrCnt + currCmd.table1numRows;
	       state <= XPROD_OUTER_RD_REQ;
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
