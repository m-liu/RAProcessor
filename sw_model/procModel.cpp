#include <iostream>     
#include <unistd.h>     
#include <cmath>        
#include <cstdio>       
#include <cstdlib>      
#include <string.h>     
#include <stdint.h>     

#include "globalTypes.h"
#include "procSelect.h"
#include "procProject.h"
#include "procUnionDiffXprod.h"

//The SW RA Processor model
//Input: command buffer
//Output: print out result of queries
//Access to: globalMem
// NO ACCESS TO ANY OTHER GLOBAL VARS!


void runProcModel (CmdEntry *cmdEntryBuff, uint32_t nCmds){
	for (uint32_t n=0; n<nCmds; n++){
		switch (cmdEntryBuff[n].op){
			case SELECT:
				doSelect(cmdEntryBuff[n]);
				break;
			case PROJECT:
				doProject(cmdEntryBuff[n]);
				break;
			case UNION:
				doUnion(cmdEntryBuff[n]);
				break;
			case DIFFERENCE:
				doDiff(cmdEntryBuff[n]);
				break;
			case XPROD:
				doXprod(cmdEntryBuff[n]);
				break;
			default:
				printf("ERROR: runProcModel: invalid command\n");
				break;
		}
	}
}
