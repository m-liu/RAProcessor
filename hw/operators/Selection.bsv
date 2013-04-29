//selection operator

import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import OperatorCommon::*;
import RowMarshaller::*;
import ControllerTypes::*;

typedef enum {SEL_IDLE, SEL_BUFFER_ROW, SEL_PROCESS_ROW, SEL_ACCEPT_ROW, SEL_WRITE_ROW, SEL_DONE_ROW} SelState deriving (Eq,Bits);

function Bool evalPredicate(Bit#(32) val1, Bit#(32) val2, CompOp op); 
	case (op)
		EQ: return (val1 == val2);
		LT: return (val1 < val2);
		LE: return (val1 <= val2);
		GT: return (val1 > val2);
		GE: return (val1 >= val2);
		NE: return (val1 != val2);
	endcase
endfunction

function Bit#(32) getPredVal0(SelClause clause, Row rowBuff);
	//always get predVal0 from column
	Bit#(32) colOffsetEx = zeroExtend(clause.colOffset0);
	Bit#(32) colBitOffset = (colOffsetEx << valueOf(TLog#(COL_WIDTH)));
	return truncateLSB( rowBuff << colBitOffset );
endfunction

function Bit#(32) getPredVal1(SelClause clause, Row rowBuff);
	//determine clause type
	if (clause.clauseType == COL_COL) begin
		Bit#(32) colOffsetEx = zeroExtend(clause.colOffset1);
		Bit#(32) colBitOffset = (colOffsetEx << valueOf(TLog#(COL_WIDTH)));
		return truncateLSB( rowBuff << colBitOffset );
	end
	else begin //if COL_VAL
		return clause.val;
	end
endfunction

//module mkSelection #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);
module mkSelection (OPERATOR_IFC);

	FIFO#(CmdEntry) cmdQ <- mkFIFO;
	FIFO#(RowAddr) ackRows <- mkFIFO;
	FIFO#(RowReq) rowReqQ <- mkFIFO;
	FIFO#(RowBurst) wdataQ <- mkFIFO;
	FIFO#(RowBurst) rdataQ <- mkFIFO;
	Reg#(SelState) state <- mkReg(SEL_IDLE);
	Reg#(Row) rowBuff <- mkReg(0);
	Reg#(RowAddr) rowBurstCnt <- mkReg(0);
	Reg#(RowAddr) outputAddrCnt <- mkReg(0);
	Reg#(RowAddr) inputAddrCnt <- mkReg(0);
	
	let currCmd = cmdQ.first();
	
	
	//send req to read rows
	rule reqRows if (state == SEL_IDLE);
		rowReqQ.enq( RowReq{ //rowAddr: currCmd.table0Addr + inputAddrCnt,
								rowAddr: currCmd.table0Addr,
								numRows: currCmd.table0numRows,
								//numRows: 1,
								reqSrc: fromInteger(valueOf(SELECTION_BLK)), 
								op: READ } );
		rowBuff <= 0;
		rowBurstCnt <= 0;
		state <= SEL_BUFFER_ROW;
	endrule

	//buffer a whole row
	rule bufferRow if (state == SEL_BUFFER_ROW);
		if (rowBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
			let rburst = rdataQ.first();
			rdataQ.deq();
			rowBuff <= (rowBuff<< valueOf(BURST_WIDTH)) | zeroExtend(rburst);
			rowBurstCnt <= rowBurstCnt+1;
		end
		else begin
			rowBurstCnt <= 0;
			inputAddrCnt <= inputAddrCnt + 1;
			state <= SEL_PROCESS_ROW;
		end
	endrule
		

	rule processRow if (state==SEL_PROCESS_ROW);
		//Important: default result values [16:0]: 1110 1110 1110 1110
		Bit#(MAX_CLAUSES) predResults = 16'hEEEE;
		for (Integer p=0; p < valueOf(MAX_CLAUSES); p=p+1) begin
			//if clause is valid, evaluate it. otherwise use default val
			if (currCmd.validClauseMask[p] == 1) begin
				let predVal0 = getPredVal0(currCmd.clauses[p], rowBuff);
				let predVal1 = getPredVal1(currCmd.clauses[p], rowBuff);
				$display("row=%x", rowBuff);
				$display("predVal0=%d, predVal1=%d", predVal0, predVal1);
				if (evalPredicate (predVal0, predVal1, currCmd.clauses[p].op)) begin
					$display("SELECT: predicate [%d] is true", p);
					predResults[p] = 1; 
				end
				else begin
					$display("SELECT: predicate [%d] is false", p);
					predResults[p] = 0; 
				end
			end
		end
		
	    $display("SELECT: row %d all predicates: %x", inputAddrCnt-1, predResults);
		let accept = ( (predResults[0] & predResults[1] & predResults[2] & predResults[3]) |
						(predResults[4] & predResults[5] & predResults[6] & predResults[7]) |
						(predResults[8] & predResults[9] & predResults[10] & predResults[11]) |
						(predResults[12] & predResults[13] & predResults[14] & predResults[15]) );

		if (accept == 1) begin
			state <= SEL_ACCEPT_ROW;
			$display("SELECT: row %d accepted", inputAddrCnt-1);
		end
		else begin
			state <= SEL_DONE_ROW;
			$display("SELECT: row %d rejected", inputAddrCnt-1);
		end
		


	endrule
	
	rule acceptRow if (state == SEL_ACCEPT_ROW);
		rowReqQ.enq( RowReq{ rowAddr: currCmd.outputAddr + outputAddrCnt,
								//numRows: currCmd.table0numRows,
								numRows: 1,
								reqSrc: fromInteger(valueOf(SELECTION_BLK)), 
								op: WRITE } );
		outputAddrCnt <= outputAddrCnt + 1;
		
		state <= SEL_WRITE_ROW;
		
	endrule

	rule writeRow if (state == SEL_WRITE_ROW);
		if (rowBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW) )) begin
			rowBurstCnt <= rowBurstCnt + 1;
			wdataQ.enq ( truncateLSB(rowBuff)  );
			rowBuff <= rowBuff << valueOf(BURST_WIDTH);
		end 
		else begin
			rowBurstCnt <= 0;
			state <= SEL_DONE_ROW;
		end
		
	endrule

	rule doneRow if (state == SEL_DONE_ROW);
		//ack, deq cmdQ
		if (inputAddrCnt >= currCmd.table0numRows) begin
			inputAddrCnt <= 0;
			cmdQ.deq();
			ackRows.enq(outputAddrCnt);
			outputAddrCnt <= 0;
			state <= SEL_IDLE;
		end
		else begin
			state <= SEL_BUFFER_ROW;
		end
		

	endrule


	//Interface definitions. 
	interface ROW_ACCESS_CLIENT_IFC rowIfc;
		method ActionValue#(RowReq) rowReq();
			rowReqQ.deq();
			return rowReqQ.first();
		endmethod
		method Action readResp (RowBurst rData);
			rdataQ.enq(rData);
		endmethod
		method ActionValue#(RowBurst) writeData();
			wdataQ.deq();
			return wdataQ.first();
		endmethod
	endinterface 

	interface CMD_SERVER_IFC cmdIfc; 

		//interface definition
		method Action pushCommand (CmdEntry cmdEntry);
			cmdQ.enq(cmdEntry);
		endmethod

		method ActionValue#( Bit#(31) ) getAckRows();
			ackRows.deq();
			return ackRows.first();
		endmethod
	endinterface


endmodule



