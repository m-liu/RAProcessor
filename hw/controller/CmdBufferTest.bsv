import GetPut::*;
import ControllerTypes::*;
import CmdBufferTypes::*;
import CmdBuffer::*;
import Vector::*;

typedef enum {IDLE, INIT, RD_REQ, RD_RESP, WR_RESP, WR_REQ, DONE} State deriving (Eq, Bits);

module mkCmdBufferTest();
   CmdBuffer cmdBuff <- mkCmdBuffer();
   Reg#(State) state <- mkReg(IDLE);
   
   Vector#(2, CmdEntry) test_data = newVector();
   test_data[0] = CmdEntry{
			   op: SELECT,
			   table0Addr: 0,
			   table0numRows: 23,
			   table0numCols: 24,
			   outputAddr: 12,
			   
			   numClauses: 0,
			   clauses: ?,
			   con: ?,
			   
			   colProjectMask:?,
			   
			   table1Addr:?,
			   table1numRows:?,
			   table1numCols:?
			   };
   
   test_data[1] = CmdEntry{
			   op: PROJECT,
			   table0Addr: 0,
			   table0numRows: 22,
			   table0numCols: 23,
			   outputAddr: 11,
			   
			   numClauses: 0,
			   clauses: ?,
			   con: ?,
			   
			   colProjectMask:?,
			   
			   table1Addr:?,
			   table1numRows:?,
			   table1numCols:?
			   };
   
   
   BuffInitLoad initLd = BuffInitLoad{index:0,
				      data:test_data[0]};
   BuffInit initOp = tagged InitLoad initLd;
   BuffInit initDone = tagged InitDone;
   
   
   rule idleBuff if (state == IDLE);
      $display("Initializing Command Buff\n");
      cmdBuff.init.request.put(initOp);
      state <= INIT;
   endrule
   
   rule initBuff if (state == INIT);
      $display("Done Initializing\n");
      cmdBuff.init.request.put(initDone);
      state <= RD_REQ;
   endrule
   
   rule rdReq if (state == RD_REQ);
      $display("Sending 1st read request\n");
      cmdBuff.req.put(BuffReq{op: Ld,
			      index: 0,
			      data: ?});
      state <= RD_RESP;
   endrule
   
   rule rdResp if (state == RD_RESP);
      $display("Receiving 1st read response\n");
      let resp <- cmdBuff.resp.get();
      $display(showCmd(resp));
      /*
      $display("CmdOp: %d\n", resp.op);
      $display("table0Addr: %d\n", resp.table0Addr);
      $display("table0numRows: %d\n", resp.table0numRows);
      $display("table0numCols: %d\n", resp.table0numCols);
      $display("outputAddr: %d\n", resp.outputAddr);
      
      $display("Sending 1st write request\n");
      cmdBuff.req.put(BuffReq{op: St,
			       addr: 0,
			      data: test_data[1]});
      */
      state <= WR_REQ;
   endrule
   
   rule wrReq if (state == WR_REQ);
      $display("Sending 2st write request\n");
      cmdBuff.req.put(BuffReq{op: Ld,
			      index: 0,
			      data: ?});
      state <= WR_RESP;
   endrule
   
   
   rule wrResp if (state == WR_RESP);
      $display("Receiving 2st read response\n");
      let resp <- cmdBuff.resp.get();
      $display(showCmd(resp));
      /*
      $display("CmdOp: %d\n", resp.op);
      $display("table0Addr: %d\n", resp.table0Addr);
      $display("table0numRows: %d\n", resp.table0numRows);
      $display("table0numCols: %d\n", resp.table0numCols);
      $display("outputAddr: %d\n", resp.outputAddr);
       */
      state <= DONE;
   endrule
   
 endmodule