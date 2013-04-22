
import GetPut::*;
import BRAM::*;

//import Types::*;
//import OperatorCommon::*;
import ControllerTypes::*;
import CmdBufferTypes::*;
//import RegFile::*;
/*
module mkMemInitRegFile(RegFile#(Bit#(16), Data) mem, MemInitIfc ifc);
    Reg#(Bool) initialized <- mkReg(False);

    interface Put request;
        method Action put(MemInit x) if (!initialized);
          case (x) matches
            tagged InitLoad .l: begin
                mem.upd(truncate(l.addr), l.data);
            end
    
            tagged InitDone: begin
                initialized <= True;
            end
          endcase
        endmethod
    endinterface
    
    method Bool done() = initialized;

endmodule
*/
module mkBuffInitBRAM(BRAM1Port#(Index, CmdEntry) mem, BuffInitIfc ifc);
    Reg#(Bool) initialized <- mkReg(False);

    interface Put request;
       method Action put(BuffInit x) if (!initialized);
          case (x) matches
             tagged InitLoad .l: begin
		//$display("update row");
                mem.portA.request.put(BRAMRequest {
                    write: True,
                    responseOnWrite: False,
                    address: l.index,
                    datain: l.data});
            end
    
             tagged InitDone: begin
		//$display("send done signal");
                initialized <= True;
            end
          endcase
        endmethod
    endinterface
    
    method Bool done() = initialized;

endmodule
