//projection operator
import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import OperatorCommon::*;
import RowMarshaller::*;
import ControllerTypes::*;

typedef enum {PROJ_IDLE, PROJ_WR_REQ, PROJ_PROCESS_ROW, PROJ_DONE_ROW} ProjState deriving (Eq,Bits);
				     

//module mkProjection #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);
module mkProjection (OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   FIFO#(RowReq) rowReqQ <- mkFIFO;
   FIFO#(RowBurst) wdataQ <- mkFIFO;
   FIFO#(RowBurst) rdataQ <- mkFIFO;
   Reg#(ProjState) state <- mkReg(PROJ_IDLE);
   //Reg#(Row) ouputBuff <- mkReg(0);
   //Reg#(TAdd#(TLog#(COL_WIDTH), 1)) rdBurstCnt <- mkReg(0);
   Reg#(Bit#(TAdd#(TLog#(COL_WIDTH), 1))) rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) wrBurstCnt <- mkReg(0);
   Reg#(RowAddr) rowCnt <- mkReg(0);

   Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule reqRows if (state == PROJ_IDLE);
      //$display("PROJ_IDLE");
      rowReqQ.enq( RowReq{
					tableAddr: currCmd.table0Addr,
					rowOffset: 0,
					//numRows: currCmd.table0numRows,
					numRows: ?,
					numCols: currCmd.table0numCols,
					reqSrc: fromInteger(valueOf(PROJECTION_BLK)), 
					reqType: REQ_ALLROWS,
					op: READ } );
      rdBurstCnt <= 0;
      wrBurstCnt <= 0;
      rowCnt <= 0;
      
      //$display("colProjMask: %b",currCmd.colProjectMask);
      colProjMask <= currCmd.colProjectMask;
      state <= PROJ_WR_REQ;
   endrule
   
   rule write_req if (state == PROJ_WR_REQ);
      //$display("PROJ_WR_REQ");
      rowReqQ.enq( RowReq{
					tableAddr: currCmd.outputAddr,
					rowOffset: 0,
//					numRows: currCmd.table0numRows,
					numRows: ?,
					numCols: currCmd.projNumCols,
					reqSrc: fromInteger(valueOf(PROJECTION_BLK)),
					reqType: REQ_ALLROWS,
					op: WRITE });
      state <= PROJ_PROCESS_ROW;
   endrule
   
   rule process_row if (state == PROJ_PROCESS_ROW);
	  // if (rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	 // if (rdBurstCnt < currCmd.table0numCols ) begin
		   let rburst = rdataQ.first();
		   rdataQ.deq();

			//check if we're at the end
			if (reduceAnd(rburst) == 1) begin
				cmdQ.deq();
				wdataQ.enq(rburst); //enq the end of table marker
				ackRows.enq(rowCnt);
				state <= PROJ_IDLE;
			end
			else begin
			   if ( colProjMask[rdBurstCnt] == 1) begin
				   wdataQ.enq(rburst);
			   //   wrBurstCnt <= wrBurstCnt+1;
			   end
			   if (rdBurstCnt == truncate(currCmd.table0numCols-1) )begin
				   rdBurstCnt <= 0;
				   rowCnt <= rowCnt+1;
			   end
			   else begin
				   rdBurstCnt <= rdBurstCnt+1;
			   end
		   end
		   //circular right shift
		   //colProjMask <= {colProjMask[0], (colProjMask >> 1)[valueOf(COL_WIDTH)-2:0]};
	   //end
	   /*
	   else begin
		   rdBurstCnt <= 0;

		   rowCnt <= rowCnt+1;
		   wrBurstCnt <= 0;
		   if (rowCnt+1 >= currCmd.table0numRows) begin
			   cmdQ.deq();
			   ackRows.enq(currCmd.table0numRows);
			   state <= PROJ_IDLE;
		   end
	   end
	   */
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
