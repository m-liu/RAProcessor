#ifndef GLOBAL_TYPES_H
#define GLOBAL_TYPES_H


#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include <stdint.h> 

#include <vector>

#define MAX_COLS 32
#define MAX_MEM_ROWS (1<<16)
#define MAX_CHARS 256
#define MAX_TABLES 128
#define MAX_NUM_CMDS 16
#define MAX_CLAUSES 16
#define MAX_AND_CLAUSES 4
#define MAX_OR_CLAUSES (MAX_CLAUSES/MAX_AND_CLAUSES)

struct TableMetaEntry {
    char tableName[MAX_CHARS];
    char colNames[MAX_COLS][MAX_CHARS];
    uint32_t numRows;
    uint32_t numCols;
    uint32_t startAddr;
};



enum CmdOp_sw {SELECT, PROJECT, UNION, DIFFERENCE, XPROD, DEDUP, RENAME}; 
enum CompOp_sw {EQ, LT, LE, GT, GE, NE}; 
enum ClauseType_sw {COL_COL, COL_VAL}; 
enum ClauseCon_sw {AND, OR}; 

struct SelClause_sw {
    ClauseType_sw clauseType;
    uint32_t colOffset0;
    uint32_t colOffset1;
    CompOp_sw op;
    long int val;
};

struct CmdEntry_sw {
    CmdOp_sw op;
    uint32_t table0Addr;
    uint32_t table0numRows;
    uint32_t table0numCols;
    uint32_t outputAddr; //Addr for output table

    //Select
    uint32_t numClauses;
    SelClause_sw clauses[MAX_CLAUSES];
    ClauseCon_sw con[MAX_CLAUSES-1]; //AND/OR connectors between clauses

    //Project
    uint32_t colProjectMask;
    uint32_t projNumCols;

    //Union/Diff/Xprod
    uint32_t table1Addr;
    uint32_t table1numRows;
    uint32_t table1numCols;


};

//Global structures   
//extern uint32_t globalMem[MAX_MEM_ROWS][MAX_COLS];
extern TableMetaEntry globalTableMeta[MAX_TABLES];
extern uint32_t globalNextMeta;
extern uint32_t globalNextAddr;

extern CmdEntry_sw globalCmdEntryBuff[MAX_NUM_CMDS];
extern uint32_t globalNCmds;

extern std::vector<uint32_t> schedule[MAX_NUM_CMDS];
extern uint32_t numScheds;

//Global access functions
/*
uint32_t getNextMeta ();
uint32_t getNextAddr (TableMetaEntry tableMeta);
*/

#endif //GLOBAL_TYPES_H
