#ifndef GLOBAL_TYPES_H
#define GLOBAL_TYPES_H


#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include <stdint.h> 

#define MAX_COLS 32
#define MAX_MEM_ROWS 4096
#define MAX_CHARS 256
#define MAX_TABLES 128


struct TableMetaEntry {
    char tableName[MAX_CHARS];
    char colNames[MAX_COLS][MAX_CHARS];
    uint32_t numRows;
    uint32_t numCols;
    uint32_t startAddr;
};



enum CmdOp {SELECT, PROJECT, XPROD, UNION, DIFFERENCE}; 

struct CmdEntry {
    CmdOp op;
    uint32_t table0Addr;
    uint32_t table0numRows;
    uint32_t table0numCols;
};

//Global structures   
uint32_t globalMem[MAX_MEM_ROWS][MAX_COLS];
TableMetaEntry globalTableMeta[MAX_TABLES];



#endif //GLOBAL_TYPES_H
