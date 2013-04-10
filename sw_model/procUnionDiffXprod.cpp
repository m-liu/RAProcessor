#include <iostream>     
#include <unistd.h>     
#include <cmath>        
#include <cstdio>       
#include <cstdlib>      
#include <string.h>     
#include <stdint.h>     

#include "globalTypes.h"

bool rowMatch (uint32_t row0_addr, uint32_t row1_addr, uint32_t num_cols){
  for ( uint32_t j = 0; j < num_cols; j++){
    if ( globalMem[row0_addr][j] != globalMem[row1_addr][j] )
      return false;
  }
  return true;
}

void updateCmdEntryBuff(uint32_t outputAddr, uint32_t updated_numRows){
  for (uint32_t i = 0; i < globalNCmds; i++){
    if ( globalCmdEntryBuff[i].table0Addr == outputAddr)
      globalCmdEntryBuff[i].table0numRows = updated_numRows;
    if ( globalCmdEntryBuff[i].table0Addr == outputAddr)
      globalCmdEntryBuff[i].table1numRows = updated_numRows;
  }
}

void doUnion (CmdEntry cmdEntry){
  uint32_t t0_addr = cmdEntry.table0Addr;
  uint32_t t1_addr = cmdEntry.table1Addr;
  uint32_t numCols = cmdEntry.table0numCols;
  uint32_t t0_numRows = cmdEntry.table0numRows;
  uint32_t t1_numRows = cmdEntry.table1numRows;
  uint32_t outputAddr = cmdEntry.outputAddr;
  
  // put the first table in the global mem
  for ( uint32_t i = 0; i < t0_numRows; i++){
    // copy rows of table0 to the output table
    memcpy(globalMem[outputAddr+i], globalMem[t0_addr+i], sizeof(uint32_t)*numCols);
  }
  
  uint32_t mismatch_cnt = 0;
  bool mismatch_flag;
  for ( uint32_t j = 0; j < t1_numRows; j++){
    mismatch_flag = true;
    for ( uint32_t i = 0; i < t0_numRows; i++){
      if ( rowMatch(t0_addr+i, t1_addr+j, numCols) ){
	mismatch_flag = false;
	break;
      }
    }
   
    if (mismatch_flag){
      memcpy(globalMem[outputAddr+t0_numRows+mismatch_cnt], globalMem[t1_addr+j], sizeof(uint32_t)*numCols);
      mismatch_cnt++;
    }
    
  }
  updateCmdEntryBuff(outputAddr, t0_numRows+mismatch_cnt);

}

void doDiff (CmdEntry cmdEntry){

  uint32_t t0_addr = cmdEntry.table0Addr;
  uint32_t t1_addr = cmdEntry.table1Addr;
  uint32_t numCols = cmdEntry.table0numCols;
  uint32_t t0_numRows = cmdEntry.table0numRows;
  uint32_t t1_numRows = cmdEntry.table1numRows;
  uint32_t outputAddr = cmdEntry.outputAddr;
  
  uint32_t mismatch_cnt = 0;
  bool mismatch_flag;
  for ( uint32_t i = 0; i < t0_numRows; i++){
    mismatch_flag = true;
    for ( uint32_t j = 0; j < t1_numRows; j++){
      if ( rowMatch(t0_addr+i, t1_addr+j, numCols) ){
	mismatch_flag = false;
	break;
      }
    }
   
    if (mismatch_flag){
      memcpy(globalMem[outputAddr+mismatch_cnt], globalMem[t0_addr+i], sizeof(uint32_t)*numCols);
      mismatch_cnt++;
    }
    
  }
  updateCmdEntryBuff(outputAddr, mismatch_cnt);
  
}

void doXprod (CmdEntry cmdEntry){
  uint32_t t0_addr = cmdEntry.table0Addr;
  uint32_t t1_addr = cmdEntry.table1Addr;
  uint32_t t0_numCols = cmdEntry.table0numCols;
  uint32_t t1_numCols = cmdEntry.table1numCols;
  uint32_t t0_numRows = cmdEntry.table0numRows;
  uint32_t t1_numRows = cmdEntry.table1numRows;
  uint32_t outputAddr = cmdEntry.outputAddr;
  
  uint32_t cnt = 0;
  for ( uint32_t i = 0; i < t0_numRows; i++){
    for ( uint32_t j = 0; j < t1_numRows; j++){
      memcpy(globalMem[outputAddr+cnt], globalMem[t0_addr+i], sizeof(uint32_t)*t0_numCols);
      memcpy(globalMem[outputAddr+cnt]+t0_numCols, globalMem[t1_addr+j], sizeof(uint32_t)*t1_numCols);
      cnt++;
    }
  }
}


