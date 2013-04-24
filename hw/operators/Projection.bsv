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
				     

module mkProjection #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);

   FIFO#(CmdEntry) cmdQ <- mkFIFO;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   Reg#(ProjState) state <- mkReg(PROJ_IDLE);
   //Reg#(Row) ouputBuff <- mkReg(0);
   Reg#(RowAddr) rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) wrBurstCnt <- mkReg(0);
   Reg#(RowAddr) rowCnt <- mkReg(0);

   Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule reqRows if (state == PROJ_IDLE);
      //$display("PROJ_IDLE");
      rowIfc.rowReq( RowReq{rowAddr: currCmd.table0Addr,
			    numRows: currCmd.table0numRows,
			    reqSrc: fromInteger(valueOf(PROJECTION_BLK)), 
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
      rowIfc.rowReq( RowReq{rowAddr: currCmd.outputAddr,
			    numRows: currCmd.table0numRows,
			    reqSrc: fromInteger(valueOf(PROJECTION_BLK)),
			    op: WRITE });
      state <= PROJ_PROCESS_ROW;
   endrule
   
   rule process_row if (state == PROJ_PROCESS_ROW);
      if (rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	 let rburst <- rowIfc.readResp();
	 if ( colProjMask[0] == 1) begin
	    rowIfc.writeData(rburst);
	    wrBurstCnt <= wrBurstCnt+1;
	 end
	 rdBurstCnt <= rdBurstCnt+1;
	 //circular right shift
	 colProjMask <= {colProjMask[0], (colProjMask >> 1)[valueOf(COL_WIDTH)-2:0]};
      end
      else begin
	 if ( wrBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	    rowIfc.writeData(0);
	    wrBurstCnt <= wrBurstCnt+1;
	 end
	 else begin
	    rowCnt <= rowCnt+1;
	    rdBurstCnt <= 0;
	    wrBurstCnt <= 0;
	    if (rowCnt+1 >= currCmd.table0numRows) begin
	       cmdQ.deq();
	       ackRows.enq(currCmd.table0numRows);
	       state <= PROJ_IDLE;
	    end
	 end
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
