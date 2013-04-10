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
#include "procDedup.h"

//The SW RA Processor model
//Input: command buffer
//Output: print out result of queries
//Access to: globalMem
// NO ACCESS TO ANY OTHER GLOBAL VARS!


void runProcModel (){
	for (uint32_t n=0; n<globalNCmds; n++){
		switch (globalCmdEntryBuff[n].op){
			case SELECT:
				doSelect(globalCmdEntryBuff[n]);
				break;
			case PROJECT:
				doProject(globalCmdEntryBuff[n]);
				break;
			case UNION:
				doUnion(globalCmdEntryBuff[n]);
				break;
			case DIFFERENCE:
				doDiff(globalCmdEntryBuff[n]);
				break;
			case XPROD:
				doXprod(globalCmdEntryBuff[n]);
				break;
			case DEDUP:
				doDedup(globalCmdEntryBuff[n]);
				break;
			default:
				printf("ERROR: runProcModel: invalid command\n");
				break;
		}
	}
}
