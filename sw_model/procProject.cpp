#include <iostream>     
#include <unistd.h>     
#include <cmath>        
#include <cstdio>       
#include <cstdlib>      
#include <string.h>     
#include <stdint.h>     

#include "globalTypes.h"



void doProject (CmdEntry cmdEntry){
  uint32_t inputAddr = cmdEntry.table0Addr;
  uint32_t outputAddr = cmdEntry.outputAddr;
  uint32_t rows = cmdEntry.table0numRows;
  uint32_t cols = cmdEntry.table0numCols;
  uint32_t mask = cmdEntry.colProjectMask;
  uint32_t outputColOffset;

  //printf("PROJECT numRows: %d", rows);
  for (uint32_t i = 0; i < rows; i++){
    outputColOffset = 0;
    for (uint32_t j = 0; j < cols; j++){    
      if ( (mask >> j) & 1 )
	globalMem[outputAddr+i][outputColOffset++] = globalMem[inputAddr+i][j];
    }
  }
  
  for (uint32_t i = 0; i < globalNCmds; i++){
    if ( globalCmdEntryBuff[i].table0Addr == outputAddr)
      globalCmdEntryBuff[i].table0numRows = rows;
    if ( globalCmdEntryBuff[i].table0Addr == outputAddr)
      globalCmdEntryBuff[i].table1numRows = rows;
  }
}
