#include <iostream>     
#include <unistd.h>     
#include <cmath>        
#include <cstdio>       
#include <cstdlib>      
#include <string.h>     
#include <stdint.h>     
                        
#include "globalTypes.h"
#include "tableParser.h"
#include "genCommand.h" 


int main(int argc, char* argv[]){
	if (argc < 2) {
		fprintf(stderr, "Input a command file\n");
		return 1;
	}

	char* csv = argv[1];

	
	if ( !parsecsv(csv, globalNextMeta, globalNextAddr) ) {
		fprintf(stderr, "MemInit Unsuccessful\n");
	}
	else{ //successful, increment global pointers
		printTable(globalNextMeta);
		globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
		globalNextMeta++;
	}

	CmdEntry cmdEntryBuff[MAX_NUM_CMDS];

	uint32_t nCmds = genCommand("input/commands.txt", cmdEntryBuff);

	for (uint32_t i=0; i<nCmds; i++){
		dumpCmdEntry(cmdEntryBuff[i]);
	}
	dumpTableMetas();
	return 0;
}
