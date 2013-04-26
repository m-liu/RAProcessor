import FIFO::*;
import GetPut::*;

//RA controller
import CmdBuffer::*;
import CmdBufferTypes::*;
import ControllerTypes::*;
import OperatorCommon::*;
import RowMarshaller::*;

typedef enum {IDLE, SENDCMD, WAITCMD,UPDATE_CMD_BUFF_REQ, UPDATE_CMD_BUFF_RESP, DONE} CtrlState deriving (Eq,Bits);


interface RAController;
   interface BuffInitIfc buffInit;
   interface Put#(Index) loadBuffSize;
   interface Get#(RowAddr) getRowAck;
endinterface

module mkRAController #(OPERATOR_IFC selectionIfc, 
			OPERATOR_IFC projectionIfc, 
			OPERATOR_IFC unionIfc, 
			OPERATOR_IFC diffIfc, 
			OPERATOR_IFC xprodIfc, 
			OPERATOR_IFC dedupIfc) (RAController);

   CmdBuffer cmdBuffer <- mkCmdBuffer();
   Reg#(CmdEntry) currCmd <- mkRegU;
   Reg#(Index) buffSize <- mkRegU();
   Reg#(Index) cnt0 <- mkReg(0);
   Reg#(Index) cnt1 <- mkReg(0);
   Reg#(Bool) loadDone <- mkReg(False);
   //Reg#(Bool) display_flag <- mkReg(True);
   Reg#(CtrlState) state <- mkReg(IDLE);
   FIFO#(RowAddr) rowAck <- mkFIFO;
   
   //Reg#(RowAddr) tableOutAddr <- mkReg(0);
   Reg#(RowAddr) numRowsReg <- mkReg(0);
   Reg#(Index) buffUpdateCnt <- mkReg(0);

//  rule display_request if (cmdBuffer.init.done() && loadDone && (cnt0 < buffSize));
//     //$display("CmdEntry %d request", cnt0);
//     
//     cmdBuffer.req.put(BuffReq{op: Ld,
//   		     index: cnt0,
//   		     data: ?});
//     cnt0 <= cnt0 + 1;
//  endrule
//
//  rule display_response if (/*cmdBuffer.init.done() &&*/ (cnt1 < buffSize));
//     $display("CmdEntry %d response", cnt1);
//     let cmd <- cmdBuffer.resp.get();
//     //IMPORTANT!::comment out next line to accelerate sim build
//     $display(showCmd(cmd));
//     cnt1 <= cnt1 + 1;
//  endrule

   rule reqNextCmd if (cmdBuffer.init.done() && loadDone && (cnt0 < buffSize) && state == IDLE);
      $display("CmdEntry %d request", cnt0);
      
      cmdBuffer.req.put(BuffReq{op: Ld,
				index: cnt0,
				data: ?});
      cnt0 <= cnt0 + 1;
      state <= SENDCMD;
   endrule

   rule sendNextCmd if (state == SENDCMD);
      $display("CmdEntry %d response", cnt1);
      let cmd <- cmdBuffer.resp.get();
	  currCmd <= cmd;
      //IMPORTANT!::comment out next line to accelerate sim build
      $display(showCmd(cmd));

	  //push the command to the corresponding operator
      case (cmd.op) 
	 SELECT: selectionIfc.pushCommand(cmd);
	 PROJECT: projectionIfc.pushCommand(cmd);
	 UNION: unionIfc.pushCommand(cmd);
	 DIFFERENCE: diffIfc.pushCommand(cmd);
	 XPROD: xprodIfc.pushCommand(cmd);
	 DEDUP: dedupIfc.pushCommand(cmd);
      endcase
      state <= WAITCMD;
   endrule

   rule waitAckCmd if (state == WAITCMD);
      RowAddr numRows = 0;
      case (currCmd.op) 
	 SELECT: numRows <- selectionIfc.getAckRows;
	 PROJECT: numRows <- projectionIfc.getAckRows;
	 UNION: numRows <- unionIfc.getAckRows;
	 DIFFERENCE: numRows <- diffIfc.getAckRows;
	 XPROD: numRows <- xprodIfc.getAckRows;
	 DEDUP: numRows <- dedupIfc.getAckRows;
      endcase

      //let numRows <- selectionIfc.getAckRows();
      $display("Controller: cmd done, numRows=%d", numRows);
      if (cnt0 < buffSize) begin
	 buffUpdateCnt <= cnt0;
	 numRowsReg <= numRows;
	 state <= UPDATE_CMD_BUFF_REQ;
      end
      else begin
	 state <= DONE; //TODO never gets out of this. TODO need to support multiple commands
	 rowAck.enq(numRows);
      end
   endrule

   rule update_buff_req if ( state == UPDATE_CMD_BUFF_REQ );
      if ( buffUpdateCnt < buffSize ) begin
	 $display("update cmdBuff %d...req sent", buffUpdateCnt);

	 cmdBuffer.req.put(BuffReq{op: Ld,
				index: buffUpdateCnt,
				   data: ?});
	 //buffUpdateCnt <= buffUpdateCnt + 1;
	 state <= UPDATE_CMD_BUFF_RESP;
      end
      else begin
	 state <= IDLE;
      end
      
   endrule
   
   rule update_buff_resp if ( state == UPDATE_CMD_BUFF_RESP );
      $display("update cmdBuff %d...resp got", buffUpdateCnt);
      let cmd <- cmdBuffer.resp.get();
      if ( currCmd.outputAddr == cmd.table0Addr ) begin
	 cmd.table0numRows = numRowsReg;
      end
      
      if ( currCmd.outputAddr == cmd.table1Addr ) begin
	 cmd.table1numRows = numRowsReg;
      end
      
      cmdBuffer.req.put(BuffReq{op: St,
				index: buffUpdateCnt,
				data: cmd});
      buffUpdateCnt <= buffUpdateCnt + 1;
      
      state <= UPDATE_CMD_BUFF_REQ;
   endrule
   
      
   
   

   
   interface BuffInitIfc buffInit = cmdBuffer.init;

   interface Put loadBuffSize;
      method Action put(Index x);
	 buffSize <= x;
	 loadDone <= True;
      endmethod
   endinterface

   interface Get getRowAck;
	   method ActionValue#(RowAddr) get();
		   rowAck.deq();
		   return rowAck.first();
	   endmethod
   endinterface

	 
endmodule
