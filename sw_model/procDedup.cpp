#include <iostream>     
#include <unistd.h>     
#include <cmath>        
#include <cstdio>       
#include <cstdlib>      
#include <string.h>     
#include <stdint.h>     

#include "globalTypes.h"

void doDedup (CmdEntry cmdEntry){

	//uint32_t rowBuff[MAX_COLS];
	uint32_t rowAddrOut = 0; 
	bool dupFound = false;

	//nested for loops to compare rows
	for (uint32_t memrow = cmdEntry.table0Addr; memrow < (cmdEntry.table0Addr+cmdEntry.table0numRows); memrow++){
		//memcpy(rowBuff, globalMem[memrow], cmdEntry.table0numCols*sizeof(uint32_t));
		dupFound = false;
		for (uint32_t rowcmp = memrow+1; rowcmp < (cmdEntry.table0Addr+cmdEntry.table0numRows); rowcmp++){
			// dup found
			if ( memcmp(globalMem[memrow], globalMem[rowcmp], cmdEntry.table0numCols*sizeof(uint32_t)) == 0) {
				dupFound = true;
				break;
			}
		}

		//if no duplicate found, store the result
		uint32_t addr;
		if (!dupFound){
			addr = cmdEntry.outputAddr + rowAddrOut;
			rowAddrOut++;
			memcpy( globalMem[addr], globalMem[memrow], cmdEntry.table0numCols*sizeof(uint32_t) );
		}

		//update cmd buff
		for (uint32_t cmdInd=0; cmdInd<globalNCmds; cmdInd++){
			//if the output table of DEDUP is the input to another command, then update the # of rows
			if ( cmdEntry.outputAddr == globalCmdEntryBuff[cmdInd].table0Addr ){ 
				globalCmdEntryBuff[cmdInd].table0numRows = rowAddrOut;
			}
			//do the same for the other input table
			if ( cmdEntry.outputAddr == globalCmdEntryBuff[cmdInd].table1Addr ){
				globalCmdEntryBuff[cmdInd].table1numRows = rowAddrOut;
			}
		}

	}
}




