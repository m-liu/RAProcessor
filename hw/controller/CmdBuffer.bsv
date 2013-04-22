
//import Types::*;
import ControllerTypes::*;
import CmdBufferTypes::*;
//import RegFile::*;;
import CmdBufferInit::*;
import BRAM::*;
import FIFO::*;
//import Fifo::*;
import GetPut::*;
//import OperatorCommon::*;

interface CmdBuffer;
    //method ActionValue#(MemResp) req(MemReq r);
   interface Put#(BuffReq) req;
      //method Action put(MemReq r);
   interface Get#(CmdEntry) resp;
      //method ActionValue#(MemResp) get();
    interface BuffInitIfc init;
endinterface

(* synthesize *)
module mkCmdBuffer(CmdBuffer);
   BRAM_Configure cfg = defaultValue;
   BRAM1Port#(Index, CmdEntry) mem <- mkBRAM1Server(cfg);
   BuffInitIfc buffInit <- mkBuffInitBRAM(mem);

   
   interface Put req;
      method Action put(BuffReq r) if (buffInit.done());
	 Bool wnr = (r.op==St) ? True: False;
	 mem.portA.request.put(BRAMRequest {write: wnr,
					 responseOnWrite: False,
					 address: r.index,
					    datain: r.data});
      endmethod
   endinterface

   interface Get resp;
      method ActionValue#(CmdEntry) get() if (buffInit.done());
	 let response <- mem.portA.response.get();
	 return response;
      endmethod
   endinterface
     
   interface BuffInitIfc init = buffInit;
endmodule

