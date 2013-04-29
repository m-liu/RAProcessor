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
   interface ROW_ACCESS_SERVER_IFC hostDataIO;
   interface DDR2Client ddr2;
   interface BuffInitIfc cmdBuffInit;
   interface Put#(Index) loadCmdBuffSize;
   interface Get#(RowAddr) getRowAck;
endinterface

(* synthesize *)
module [Module] mkRAProcessor(RAProcessor);
   ROW_MARSHALLER_IFC rowMarshaller <- mkRowMarshaller();
   
//   OPERATOR_IFC selectionOp <- mkSelection(rowMarshaller.rowAccesses[valueOf(SELECTION_BLK)]);
//   OPERATOR_IFC projectionOp <- mkProjection(rowMarshaller.rowAccesses[valueOf(PROJECTION_BLK)]);
//   OPERATOR_IFC unionOp <- mkUnion(rowMarshaller.rowAccesses[valueOf(UNION_BLK)]);
//   OPERATOR_IFC diffOp <- mkDifference(rowMarshaller.rowAccesses[valueOf(DIFFERENCE_BLK)]);
//   OPERATOR_IFC xprodOp <- mkXprod(rowMarshaller.rowAccesses[valueOf(XPROD_BLK)]);
//   OPERATOR_IFC dedupOp <- mkDedup(rowMarshaller.rowAccesses[valueOf(DEDUP_BLK)]);

   OPERATOR_IFC selectionOp <- mkSelection();
   OPERATOR_IFC projectionOp <- mkProjection();
   OPERATOR_IFC unionOp <- mkUnion();
   OPERATOR_IFC diffOp <- mkDifference();
   OPERATOR_IFC xprodOp <- mkXprod();
   OPERATOR_IFC dedupOp <- mkDedup();
   
   RAController raController <- mkRAController();
   
   //connect row marshaller to all the operators
   mkConnection(rowMarshaller.rowAccesses[valueOf(SELECTION_BLK)], selectionOp.rowIfc);
   mkConnection(rowMarshaller.rowAccesses[valueOf(PROJECTION_BLK)], projectionOp.rowIfc);
   mkConnection(rowMarshaller.rowAccesses[valueOf(UNION_BLK)], unionOp.rowIfc);
   mkConnection(rowMarshaller.rowAccesses[valueOf(DIFFERENCE_BLK)], diffOp.rowIfc);
   mkConnection(rowMarshaller.rowAccesses[valueOf(XPROD_BLK)], xprodOp.rowIfc);
   mkConnection(rowMarshaller.rowAccesses[valueOf(DEDUP_BLK)], dedupOp.rowIfc);

   //connect the controller to all the operators
   mkConnection(selectionOp.cmdIfc, raController.cmdIfcs[valueOf(SELECTION_BLK)]);
   mkConnection(projectionOp.cmdIfc, raController.cmdIfcs[valueOf(PROJECTION_BLK)]);
   mkConnection(unionOp.cmdIfc, raController.cmdIfcs[valueOf(UNION_BLK)]);
   mkConnection(diffOp.cmdIfc, raController.cmdIfcs[valueOf(DIFFERENCE_BLK)]);
   mkConnection(xprodOp.cmdIfc, raController.cmdIfcs[valueOf(XPROD_BLK)]);
   mkConnection(dedupOp.cmdIfc, raController.cmdIfcs[valueOf(DEDUP_BLK)]);


   interface ROW_ACCESS_IFC hostDataIO = rowMarshaller.rowAccesses[valueOf(DATA_IO_BLK)];
   
   interface DDR2Client ddr2 = rowMarshaller.ddrMem;
      
   interface BuffInitIfc cmdBuffInit = raController.buffInit;

   interface Put loadCmdBuffSize = raController.loadBuffSize;

   interface Get getRowAck = raController.getRowAck;
      
endmodule
