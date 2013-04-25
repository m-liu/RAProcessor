import FIFO::*;
import GetPut::*;

//RA controller
import CmdBuffer::*;
import CmdBufferTypes::*;
import ControllerTypes::*;
import OperatorCommon::*;
import RowMarshaller::*;

typedef enum {IDLE, SENDCMD, WAITCMD, DONE} CtrlState deriving (Eq,Bits);


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
      //$display("CmdEntry %d request", cnt0);
      
      cmdBuffer.req.put(BuffReq{op: Ld,
    		     index: cnt0,
    		     data: ?});
      cnt0 <= cnt0 + 1;
	  state <= SENDCMD;
   endrule

   rule sendNextCmd if (state == SENDCMD);
      //$display("CmdEntry %d response", cnt1);
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
	  	state <= IDLE;
	  end
	  else begin
		state <= DONE; //TODO never gets out of this. TODO need to support multiple commands
		rowAck.enq(numRows);
      end
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
