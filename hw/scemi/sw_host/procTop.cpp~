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


	globalNCmds = genCommand(cmdIn, globalCmdEntryBuff);

	printf("command dump BEFORE execution:\n");
	for (uint32_t i=0; i<globalNCmds; i++){
		dumpCmdEntry(globalCmdEntryBuff[i]);
	}

	runProcModel();

	printf("command dump AFTER execution:\n");
	for (uint32_t i=0; i<globalNCmds; i++){
		dumpCmdEntry(globalCmdEntryBuff[i]);
	}
	dumpTableMetas();

	printf("\n************************************\n");
	printf("Final table values:\n");
	for (uint32_t i=0; i<globalNextMeta; i++){
		printTable(i);
	}

	return 0;
}
