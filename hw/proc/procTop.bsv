//top BSV file of RA processor

import RowMarshaller::*;
import CmdBufferTypes::*;
import Controller::*;
import XilinxDDR2::*;
import DDR2::*;
import Connectable::*;
import GetPut::*;
import ControllerTypes::*;

interface RAProcessor;
   interface ROW_ACCESS_IFC hostDataIO;
   interface DDR2Client ddr2;
   interface BuffInitIfc cmdBuffInit;
   interface Put#(Index) loadCmdBuffSize;
endinterface

module [Module] mkRAProcessor(RAProcessor);
   ROW_MARSHALLER_IFC rowMarshaller <- mkRowMarshaller();
   RAController raController <- mkRAController();
   
   interface ROW_ACCESS_IFC hostDataIO = rowMarshaller.rowAccesses[0];
   
   interface DDR2Client ddr2 = rowMarshaller.ddrMem;
      
   interface BuffInitIfc cmdBuffInit = raController.buffInit;

   interface Put loadCmdBuffSize = raController.loadBuffSize;
      
endmodule