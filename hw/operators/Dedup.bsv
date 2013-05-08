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
				     

//module mkDedup #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);
(* synthesize *)
module mkDedup (BINARY_OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   FIFO#(RowReq) rowReqQ <- mkFIFO;
   FIFO#(RowBurst) wdataQ <- mkFIFO;
   FIFO#(RowBurst) rdataQ <- mkFIFO;
   Reg#(DedupState) state <- mkReg(DEDUP_IDLE);
   //Reg#(Row) ouputBuff <- mkReg(0);
   
   Vector#(BURSTS_PER_ROW, Reg#(RowBurst)) rowBuff <- replicateM(mkRegU());
   Reg#(RowAddr) inputAddrCnt <- mkReg(0);
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

   Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule dedup_idle if (state == DEDUP_IDLE);
      //$display("IDLE");
      inputAddrCnt <= 0;
      outputAddrCnt <= 0;
      outer_rdBurstCnt <= 0;
      inner_rdBurstCnt <= 0;
      wrBurstCnt <= 0;
      //table0ColCnt <= 0;
      //outer_rowCnt <= 0;
      //inner_rowCnt <= 0;
      //total_rowCnt <= 0;
      state <= DEDUP_CP_TABLE0_RD_REQ;
	  //if output to memory, make the request
	  if (currCmd.outputDest == MEMORY) begin
      	rowReqQ.enq(RowReq{tableAddr: currCmd.outputAddr,
			 rowOffset: 0,
			 numRows: ?,
			 numCols: ?,
			 reqSrc: fromInteger(valueOf(DEDUP_BLK)),
			 reqType: REQ_ALLROWS,
			 op: WRITE });
	   end
   endrule
   
   rule outer_loop_rd_req if (state == DEDUP_CP_TABLE0_RD_REQ);
      $display("DEDUP_CP_TABLE1_RD_REQ");
      
      $display("table0Addr: %d", currCmd.table0Addr);
      $display("inputAddrCnt: %d", inputAddrCnt);
      rowReqQ.enq( RowReq{tableAddr: currCmd.table0Addr,
			  rowOffset: inputAddrCnt,
			  numRows: 1,
			  numCols: currCmd.table0numCols,
			  reqSrc: fromInteger(valueOf(DEDUP_BLK)),
			  reqType: REQ_NROWS,
			  op: READ });
      inputAddrCnt <= inputAddrCnt + 1;
      state <= DEDUP_OUTER_BUFF_ROW;
      
   endrule
   
   rule outer_loop_rd_resp if (state == DEDUP_OUTER_BUFF_ROW);
      $display("DEDUP_OUTER_BUFF_ROW");
      if (outer_rdBurstCnt < currCmd.table0numCols) begin
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
	    state <= DEDUP_IDLE;
	    wdataQ.enq(-1);
	    /*
	    rowReqQ.enq(RowReq{tableAddr: currCmd.outputAddr,
			 rowOffset: outputAddrCnt,
			 numRows: 8,
			 numCols: currCmd.table0numCols,
			 reqSrc: fromInteger(valueOf(DEDUP_BLK)),
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
	    
	    $display("table0Addr: %d", currCmd.table0Addr);
	    $display("inputAddrCnt: %d", inputAddrCnt);
	    //$finish;
	    rowReqQ.enq( RowReq{tableAddr: currCmd.table0Addr,
				rowOffset: inputAddrCnt,
				numRows: ?,
				numCols: currCmd.table0numCols,
				reqSrc: fromInteger(valueOf(DEDUP_BLK)),
				reqType: REQ_ALLROWS,
				op: READ });
	    state <= DEDUP_PROCESS_ROW;
	 end
      end
      
   endrule
    
   rule process_row if (state == DEDUP_PROCESS_ROW);
      $display("DEDUP_PROCESS_ROW");
      if ( inner_rdBurstCnt < currCmd.table0numCols ) begin
	 let rBurst = rdataQ.first();
	 rdataQ.deq();
	 $display("rBurst = %h", rBurst);
	 if ( reduceAnd(rBurst) == 1 ) begin
	       //rdataQ.deq();
	       if ( scan_rows ) begin
		  $display("no match found");
		  state <= DEDUP_CP_TABLE0_WR_ROW;
		  outputAddrCnt <= outputAddrCnt + 1;
	       end
	       else begin
		  $display("match found");
		  state <= DEDUP_CP_TABLE0_RD_REQ;
	       end
	    end
	 else begin
	    if ( scan_rows &&& rBurst != rowBuff[inner_rdBurstCnt] ) begin
	       //$display("mismatch found");
	       match_found <= False;
	    end	 
	    inner_rdBurstCnt <= inner_rdBurstCnt + 1;
	 end
	 
      end
      else begin
	 match_found <= True;
	 inner_rdBurstCnt <= 0;
	 if ( match_found == True ) begin
	    //$display("matching row found");
	    scan_rows <= False;
	    //match_found <= False;
	 end
	 
      end	  
   endrule
   /*
   rule cp_table1_wr_req if ( state == DEDUP_CP_TABLE0_WR_REQ);
      rowReqQ.enq(RowReq{tableAddr: currCmd.outputAddr,
			 rowOffset: outputAddrCnt,
			 numRows: 1,
			 numCols: currCmd.table0numCols,
			 reqSrc: fromInteger(valueOf(DEDUP_BLK)),
			 reqType: REQ_NROWS,
			 op: WRITE });
      
      
      state <= DEDUP_CP_TABLE0_WR_ROW;
   endrule
   */
   rule cp_table1_wr_row if ( state == DEDUP_CP_TABLE0_WR_ROW );
      if ( wrBurstCnt < currCmd.table0numCols ) begin
	  wdataQ.enq(rowBuff[wrBurstCnt]);
	 wrBurstCnt <= wrBurstCnt + 1;
      end
      else begin
	 wrBurstCnt <= 0;
	 state <= DEDUP_CP_TABLE0_RD_REQ;
      end
   endrule
   
	 
	//interface vector
   Vector#(NUM_BINARY_INTEROP_OUT, INTEROP_SERVER_IFC) interOut = newVector();
	for (Integer ind=0; ind < valueOf(NUM_BINARY_INTEROP_OUT); ind=ind+1) begin
	 	interOut[ind] = interface INTEROP_SERVER_IFC; 
							method ActionValue#(RowBurst) readResp();
								wdataQ.deq();
								return wdataQ.first();
							endmethod
						endinterface;
	end
   


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

	interface interOutIfc = interOut;


endmodule
