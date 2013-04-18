
import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import RowMarshaller::*;

//TODO perhaps this should be moved to controller.bsv
typedef 16 MAX_CLAUSES;

typedef enum {SELECT, PROJECT, UNION, DIFFERENCE, XPROD, DEDUP, RENAME} CmdOp deriving (Eq,Bits);

typedef enum {EQ, LT, LE, GT, GE, NE} CompOp deriving (Eq,Bits);
typedef enum {COL_COL, COL_VAL} ClauseType deriving (Eq,Bits);
typedef enum {AND, OR} ClauseCon deriving (Eq,Bits);

typedef struct {
	ClauseType clauseType;
	Bit#(TLog#(MAX_COLS)) colOffset0;
	Bit#(TLog#(MAX_COLS)) colOffset1;
	CompOp op;
	Bit#(COL_WIDTH) val;
} SelClause deriving (Eq,Bits);

typedef struct {
	CmdOp op;
	RowAddr table0Addr;
	RowAddr table0numRows;
	RowAddr table0numCols;
	RowAddr outputAddr;

	//Select
	Bit#(TLog#(MAX_CLAUSES)) numClauses;
	Vector#(MAX_CLAUSES, SelClause) clauses;
	//AND/OR connectors between clauses
	Vector#(TSub#(MAX_CLAUSES,1), ClauseCon) con; 

	//Project
	Bit#(COL_WIDTH) colProjectMask;

	//Union/Diff/Xprod
	RowAddr table1Addr;
	RowAddr table1numRows;
	RowAddr table1numCols;
} CmdEntry deriving (Eq, Bits);

//TODO side interface to other operators


interface OPERATOR_IFC;
	method Action pushCommand (CmdEntry cmdEntry);
	method ActionValue#( RowAddr ) getAckRows();
endinterface










/*

enum CmdOp {SELECT, PROJECT, UNION, DIFFERENCE, XPROD, DEDUP, RENAME};
enum CompOp {EQ, LT, LE, GT, GE, NE};
enum ClauseType {COL_COL, COL_VAL};
enum ClauseCon {AND, OR};

struct SelClause {
	ClauseType clauseType;
	uint32_t colOffset0;
	uint32_t colOffset1;
	CompOp op;
	long int val;
};

struct CmdEntry {
	CmdOp op;
	uint32_t table0Addr;
	uint32_t table0numRows;
	uint32_t table0numCols;
	uint32_t outputAddr; //Addr for output table

	//Select
	uint32_t numClauses;
	SelClause clauses[MAX_CLAUSES];
	ClauseCon con[MAX_CLAUSES-1]; //AND/OR connectors between clauses

	//Project
	uint32_t colProjectMask;

	//Union/Diff/Xprod
	uint32_t table1Addr;
	uint32_t table1numRows;
	uint32_t table1numCols;


};
*/
