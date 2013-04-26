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
import Projection::*;
import Union::*;
import Difference::*;
import Xprod::*;
import Dedup::*;

interface RAProcessor;
   interface ROW_ACCESS_IFC hostDataIO;
   interface DDR2Client ddr2;
   interface BuffInitIfc cmdBuffInit;
   interface Put#(Index) loadCmdBuffSize;
   interface Get#(RowAddr) getRowAck;
endinterface

(* synthesize *)
module [Module] mkRAProcessor(RAProcessor);
   ROW_MARSHALLER_IFC rowMarshaller <- mkRowMarshaller();
   
   OPERATOR_IFC selectionOp <- mkSelection(rowMarshaller.rowAccesses[valueOf(SELECTION_BLK)]);
   OPERATOR_IFC projectionOp <- mkProjection(rowMarshaller.rowAccesses[valueOf(PROJECTION_BLK)]);
   OPERATOR_IFC unionOp <- mkUnion(rowMarshaller.rowAccesses[valueOf(UNION_BLK)]);
   OPERATOR_IFC diffOp <- mkDifference(rowMarshaller.rowAccesses[valueOf(DIFFERENCE_BLK)]);
   OPERATOR_IFC xprodOp <- mkXprod(rowMarshaller.rowAccesses[valueOf(XPROD_BLK)]);
   OPERATOR_IFC dedupOp <- mkDedup(rowMarshaller.rowAccesses[valueOf(DEDUP_BLK)]);
   
   RAController raController <- mkRAController(selectionOp, projectionOp, unionOp, diffOp, xprodOp, dedupOp);

   interface ROW_ACCESS_IFC hostDataIO = rowMarshaller.rowAccesses[valueOf(DATA_IO_BLK)];
   
   interface DDR2Client ddr2 = rowMarshaller.ddrMem;
      
   interface BuffInitIfc cmdBuffInit = raController.buffInit;

   interface Put loadCmdBuffSize = raController.loadBuffSize;

   interface Get getRowAck = raController.getRowAck;
      
endmodule
