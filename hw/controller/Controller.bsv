import FIFO::*;
import GetPut::*;
import Vector::*;

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

   interface Vector#(NUM_MODULES, CMD_CLIENT_IFC) cmdIfcs;
endinterface

//module mkRAController #(OPERATOR_IFC selectionIfc, 
//			OPERATOR_IFC projectionIfc, 
//			OPERATOR_IFC unionIfc, 
//			OPERATOR_IFC diffIfc, 
//			OPERATOR_IFC xprodIfc, 
//			OPERATOR_IFC dedupIfc) (RAController);

(* synthesize *)
module mkRAController (RAController);

	//FIFO going out to the operators and acks coming back from them
	Vector#(NUM_MODULES, FIFO#(CmdEntry)) cmdOuts <- replicateM(mkFIFO);
	Vector#(NUM_MODULES, FIFO#(RowAddr)) rowAckIns <- replicateM(mkFIFO);


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
		  SELECT: cmdOuts[valueOf(SELECTION_BLK)].enq(cmd);
		  PROJECT: cmdOuts[valueOf(PROJECTION_BLK)].enq(cmd);
		  UNION: cmdOuts[valueOf(UNION_BLK)].enq(cmd);
		  DIFFERENCE: cmdOuts[valueOf(DIFFERENCE_BLK)].enq(cmd);
		  XPROD: cmdOuts[valueOf(XPROD_BLK)].enq(cmd);
		  DEDUP: cmdOuts[valueOf(DEDUP_BLK)].enq(cmd);
      endcase
      state <= WAITCMD;
   endrule

   rule waitAckCmd if (state == WAITCMD);
	   RowAddr numRows = 0;
	   case (currCmd.op) 
			SELECT:	begin 
			    		numRows = rowAckIns[valueOf(SELECTION_BLK)].first;
			    		rowAckIns[valueOf(SELECTION_BLK)].deq();
					end
			PROJECT: begin
			    		numRows = rowAckIns[valueOf(PROJECTION_BLK)].first;
			    		rowAckIns[valueOf(PROJECTION_BLK)].deq();
					end
			UNION: begin
			    		numRows = rowAckIns[valueOf(UNION_BLK)].first;
			    		rowAckIns[valueOf(UNION_BLK)].deq();
					end
			DIFFERENCE: begin
			    		numRows = rowAckIns[valueOf(DIFFERENCE_BLK)].first;
			    		rowAckIns[valueOf(DIFFERENCE_BLK)].deq();
					end
			XPROD:	begin
			    		numRows = rowAckIns[valueOf(XPROD_BLK)].first;
			    		rowAckIns[valueOf(XPROD_BLK)].deq();
					end
			DEDUP: 	begin
			    		numRows = rowAckIns[valueOf(DEDUP_BLK)].first;
			    		rowAckIns[valueOf(DEDUP_BLK)].deq();
					end
	   endcase

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
   
      
   
   Vector#(NUM_MODULES, CMD_CLIENT_IFC) cmdInterfaces = newVector();

   for (Integer moduleInd=0; moduleInd < valueOf(NUM_MODULES); moduleInd=moduleInd+1)
   begin
	   cmdInterfaces[moduleInd] = interface CMD_CLIENT_IFC; 
	   							method ActionValue#(CmdEntry) pushCommand();
									cmdOuts[moduleInd].deq();
									return cmdOuts[moduleInd].first;
								endmethod

								method Action getAckRows( RowAddr nRows ); //from ops
									rowAckIns[moduleInd].enq(nRows);
								endmethod
							endinterface;
	end

   interface cmdIfcs = cmdInterfaces;

   
   interface BuffInitIfc buffInit = cmdBuffer.init;

   interface Put loadBuffSize;
      method Action put(Index x);
	 buffSize <= x;
	 loadDone <= True;
      endmethod
   endinterface

   interface Get getRowAck; //To SCEMI
	   method ActionValue#(RowAddr) get();
		   rowAck.deq();
		   return rowAck.first();
	   endmethod
   endinterface

	 
endmodule
