//RA controller
import CmdBuffer::*;
import CmdBufferTypes::*;
import ControllerTypes::*;

import GetPut::*;

interface RAController;
   interface BuffInitIfc buffInit;
   interface Put#(Index) loadBuffSize;
endinterface

module mkRAController(RAController);
   CmdBuffer cmdBuffer <- mkCmdBuffer();
   Reg#(Index) buffSize <- mkRegU();
   Reg#(Index) cnt0 <- mkReg(0);
   Reg#(Index) cnt1 <- mkReg(0);
   Reg#(Bool) loadDone <- mkReg(False);
   //Reg#(Bool) display_flag <- mkReg(True);

   rule display_request if (cmdBuffer.init.done() && loadDone && (cnt0 < buffSize));
      //$display("CmdEntry %d request", cnt0);
      
      cmdBuffer.req.put(BuffReq{op: Ld,
			     index: cnt0,
			     data: ?});
      cnt0 <= cnt0 + 1;
   endrule

   rule display_response if (/*cmdBuffer.init.done() &&*/ (cnt1 < buffSize));
      $display("CmdEntry %d response", cnt1);
      let cmd <- cmdBuffer.resp.get();
      //IMPORTANT!::comment out next line to accelerate sim build
      $display(showCmd(cmd));
      cnt1 <= cnt1 + 1;
   endrule
   

   
   interface BuffInitIfc buffInit = cmdBuffer.init;

   interface Put loadBuffSize;
      method Action put(Index x);
	 buffSize <= x;
	 loadDone <= True;
      endmethod
   endinterface
	 
endmodule
