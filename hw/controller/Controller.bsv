import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;

//RA controller
import CmdBuffer::*;
import CmdBufferTypes::*;
import ControllerTypes::*;
import OperatorCommon::*;
import RowMarshaller::*;

typedef enum {SENDCMD, WAITCMD, IDLE, UPDATE_CMD_BUFF_REQ, UPDATE_CMD_BUFF_RESP, DONE} CtrlState deriving (Eq,Bits);


interface RAController;
   interface BuffInitIfc buffInit;
   interface Put#(Index) loadBuffSize;
   interface Get#(RowAddr) getRowAck;
   interface Get#(Cycles) getCycles;
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
   //Reg#(CmdEntry) currCmd <- mkRegU;
   FIFOF#(CmdOp) activeCmdQ <- mkSizedFIFOF(8); //track what operators are active
   Reg#(Index) buffSize <- mkRegU();
   Reg#(Index) cnt0 <- mkReg(0);
//   Reg#(Index) cnt1 <- mkReg(0);
   Reg#(Bool) loadDone <- mkReg(False);
   //Reg#(Bool) display_flag <- mkReg(True);
   Reg#(CtrlState) state <- mkReg(IDLE);
   FIFO#(RowAddr) rowAck <- mkFIFO;
   
   //Reg#(RowAddr) tableOutAddr <- mkReg(0);
   Reg#(RowAddr) numRowsReg <- mkReg(0);
   Reg#(Index) buffUpdateCnt <- mkReg(0);
   
   
   //benchmark counters
	//make sure we have enough space for the counters
   FIFO#(Cycles) cycleAck <- mkSizedFIFO(valueOf(MAX_NUM_CMDS)+1); 
   Reg#(Bit#(64)) totalCnt <- mkReg(0);
   Reg#(Bool) enTotalCnt <- mkReg(False);
   
   Reg#(Bit#(64)) selStartCnt <- mkReg(0);
   Reg#(Bit#(64)) projStartCnt <- mkReg(0);
   Reg#(Bit#(64)) xprodStartCnt <- mkReg(0);
   Reg#(Bit#(64)) diffStartCnt <- mkReg(0);
   Reg#(Bit#(64)) unionStartCnt <- mkReg(0);
   Reg#(Bit#(64)) dedupStartCnt <- mkReg(0);

 /*  
   rule cnt_increment if (cmdBuffer.init.done() && loadDone && (cnt0 < buffSize) && state != DONE);
      totalCnt <= totalCnt + 1;
      //$display(totalCnt);
   endrule
*/

   /*
   rule display_cnt;// if (cmdBuffer.init.done() && loadDone && (cnt0 < buffSize) && state != DONE);
      $display(totalCnt);
   endrule
    */
   
   
	rule incrCnt;
		if (enTotalCnt) totalCnt <= totalCnt + 1;
		else totalCnt <= 0;
	endrule


   rule reqNextCmd if (cmdBuffer.init.done() && loadDone && (cnt0 < buffSize) && state == IDLE);
      enTotalCnt <= True;

      $display("Controller: CmdEntry %d request", cnt0);
      
      cmdBuffer.req.put(BuffReq{op: Ld,
				index: cnt0,
				data: ?});
      cnt0 <= cnt0 + 1;
      state <= SENDCMD;
   endrule

   rule sendNextCmd if (state == SENDCMD);
      $display("Controller: got CmdEntry response");
      let cmd <- cmdBuffer.resp.get();
      //currCmd <= cmd;
      activeCmdQ.enq(cmd.op);
      //IMPORTANT!::comment out next line to accelerate sim build
      $display(showCmd(cmd));

      //push the command to the corresponding operator
		case (cmd.op) 
			SELECT: begin
						cmdOuts[valueOf(SELECTION_BLK)].enq(cmd);
						selStartCnt <= totalCnt;
					end
			PROJECT: begin
						cmdOuts[valueOf(PROJECTION_BLK)].enq(cmd);
						projStartCnt <= totalCnt;
					end
			UNION: begin
						cmdOuts[valueOf(UNION_BLK)].enq(cmd);
						unionStartCnt <= totalCnt;
					end
			DIFFERENCE: begin
						cmdOuts[valueOf(DIFFERENCE_BLK)].enq(cmd);
						diffStartCnt <= totalCnt;
					end
			XPROD: begin
						cmdOuts[valueOf(XPROD_BLK)].enq(cmd);
						xprodStartCnt <= totalCnt;
					end
			DEDUP: begin
						cmdOuts[valueOf(DEDUP_BLK)].enq(cmd);
						dedupStartCnt <= totalCnt;
					end
		endcase

      //keep getting cmds if the outputdest isn't memory
      if (cmd.outputDest != MEMORY) begin
	 state <= IDLE;
	 $display("Controller: issuing another command at the same time");
      end
      else begin
	 state <= WAITCMD;
      end
      
   endrule
   
   rule waitAckCmd if (state == WAITCMD);
      RowAddr numRows = 0;
      if (activeCmdQ.notEmpty) begin
         case (activeCmdQ.first) 
            SELECT: begin 
                   numRows = rowAckIns[valueOf(SELECTION_BLK)].first;
                   rowAckIns[valueOf(SELECTION_BLK)].deq();
                   activeCmdQ.deq();
					//sel perf count
					let selCnt = totalCnt - selStartCnt;
					cycleAck.enq(tuple2(SELECT, selCnt));
                   $display("Controller: SELECT ack received, numRows=%d", numRows);
                end
            PROJECT: begin
                	numRows = rowAckIns[valueOf(PROJECTION_BLK)].first;
                	rowAckIns[valueOf(PROJECTION_BLK)].deq();
                	activeCmdQ.deq();
					//proj perf count
					let projCnt = totalCnt - projStartCnt;
					cycleAck.enq(tuple2(PROJECT, projCnt));
                	$display("Controller: PROJECT ack received, numRows=%d", numRows);
                 end
            UNION: begin
                  numRows = rowAckIns[valueOf(UNION_BLK)].first;
                  rowAckIns[valueOf(UNION_BLK)].deq();
                  activeCmdQ.deq();
					//union perf count
					let unionCnt = totalCnt - unionStartCnt;
					cycleAck.enq(tuple2(UNION, unionCnt));
                  $display("Controller: UNION ack received, numRows=%d", numRows);
               end
            DIFFERENCE: begin
                   numRows = rowAckIns[valueOf(DIFFERENCE_BLK)].first;
                   rowAckIns[valueOf(DIFFERENCE_BLK)].deq();
                   activeCmdQ.deq();
					//diff perf count
					let diffCnt = totalCnt - diffStartCnt;
					cycleAck.enq(tuple2(DIFFERENCE, diffCnt));
                   $display("Controller: DIFF ack received, numRows=%d", numRows);
                end
            XPROD: begin
                  numRows = rowAckIns[valueOf(XPROD_BLK)].first;
                  rowAckIns[valueOf(XPROD_BLK)].deq();
                  activeCmdQ.deq();
					//xprod perf count
					let xprodCnt = totalCnt - xprodStartCnt;
					cycleAck.enq(tuple2(XPROD, xprodCnt));
                  $display("Controller: XPROD ack received, numRows=%d", numRows);
               end
            DEDUP: begin
                  numRows = rowAckIns[valueOf(DEDUP_BLK)].first;
                  rowAckIns[valueOf(DEDUP_BLK)].deq();
                  activeCmdQ.deq();
					//dedup perf count
					let dedupCnt = totalCnt - dedupStartCnt;
					cycleAck.enq(tuple2(DEDUP, dedupCnt));
                  $display("Controller: DEDUP ack received, numRows=%d", numRows);
               end
	    endcase
      end
      else begin
             $display("Controller: Done with a set of commands");
             if (cnt0 < buffSize) begin
                //buffUpdateCnt <= cnt0;
                //numRowsReg <= numRows;
                //state <= UPDATE_CMD_BUFF_REQ;
                state <= IDLE;
             end
             else begin
                $display("Controller: ALL DONE");
                state <= DONE; //TODO never gets out of this. TODO need to support multiple commands
                rowAck.enq(numRows);
				cycleAck.enq(tuple2(CONTROLLER, totalCnt));
             end
      end
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
   
   interface Get getCycles; //To SCEMI
      method ActionValue#(Cycles) get();
	 cycleAck.deq();
	 return cycleAck.first();
      endmethod
   endinterface
	 
endmodule













/*
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
   
*/      
   
