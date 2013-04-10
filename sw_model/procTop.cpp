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
#include "procModel.h"

int main(int argc, char* argv[]){
	if (argc < 2) {
		fprintf(stderr, "Input a command file\n");
		return 1;
	}

	char* cmdIn = argv[1];

	printf("\nReading the CSV files in directory ./input/.........\n");
	if ( !parsecsv() ) {
		fprintf(stderr, "MemInit Unsuccessful\n");
	}
	else{
	  printf("CSV files Read Successful, Memory Initialized!...........\n\n");
	}

	CmdEntry cmdEntryBuff[MAX_NUM_CMDS];

	uint32_t nCmds = genCommand(cmdIn, cmdEntryBuff);

	runProcModel(cmdEntryBuff, nCmds);

	for (uint32_t i=0; i<nCmds; i++){
		dumpCmdEntry(cmdEntryBuff[i]);
	}
	dumpTableMetas();

	printf("\n************************************\n");
	printf("Final table values:\n");
	for (uint32_t i=0; i<globalNextMeta; i++){
		printTable(i);
	}

	return 0;
}
