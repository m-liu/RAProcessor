//top BSV file of RA processor

import RowMarshaller::*;
import CmdBufferTypes::*;
import Controller::*;
import XilinxDDR2::*;
import DDR2::*;
import Connectable::*;
import GetPut::*;
import ControllerTypes::*;
import OperatorCommon::*;

import Selection::*;

interface RAProcessor;
   interface ROW_ACCESS_IFC hostDataIO;
   interface DDR2Client ddr2;
   interface BuffInitIfc cmdBuffInit;
   interface Put#(Index) loadCmdBuffSize;
   interface Get#(RowAddr) getRowAck;
endinterface

module [Module] mkRAProcessor(RAProcessor);
   ROW_MARSHALLER_IFC rowMarshaller <- mkRowMarshaller();
   
   OPERATOR_IFC selection <- mkSelection(rowMarshaller.rowAccesses[valueOf(SELECTION_BLK)]);
   
   RAController raController <- mkRAController(selection);

   interface ROW_ACCESS_IFC hostDataIO = rowMarshaller.rowAccesses[valueOf(DATA_IO_BLK)];
   
   interface DDR2Client ddr2 = rowMarshaller.ddrMem;
      
   interface BuffInitIfc cmdBuffInit = raController.buffInit;

   interface Put loadCmdBuffSize = raController.loadBuffSize;

   interface Get getRowAck = raController.getRowAck;
      
endmodule
