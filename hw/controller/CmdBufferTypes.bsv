
import GetPut::*;
import ControllerTypes::*;
//import OperatorCommon::*;

typedef 16 MAX_NUM_CMDS;
typedef TLog#(MAX_NUM_CMDS) INDEXWIDTH;
typedef Bit#(INDEXWIDTH) Index;




//typedef Data Line;

//typedef Line MemResp;

typedef enum{Ld, St} MemOp deriving(Eq,Bits);
typedef struct{
    MemOp op;
    Index index;
    CmdEntry  data;
} BuffReq deriving(Eq,Bits);
/*
typedef 16 NumTokens;
typedef Bit#(TLog#(NumTokens)) Token;

typedef 16 LoadBufferSz;
typedef Bit#(TLog#(LoadBufferSz)) LoadBufferIndex;
*/
typedef struct {
    Index index;
    CmdEntry data;
} BuffInitLoad deriving(Eq, Bits);

typedef union tagged {
   BuffInitLoad InitLoad;
   void InitDone;
} BuffInit deriving(Eq, Bits);

interface BuffInitIfc;
  interface Put#(BuffInit) request;
  method Bool done();
endinterface

