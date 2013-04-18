#include "globalTypes.h"


//Global structures   
//uint32_t globalMem[MAX_MEM_ROWS][MAX_COLS];
TableMetaEntry globalTableMeta[MAX_TABLES];
uint32_t globalNextMeta = 0;
uint32_t globalNextAddr = 0;

CmdEntry globalCmdEntryBuff[MAX_NUM_CMDS];
uint32_t globalNCmds = 0;


/*
uint32_t getNextMeta (){
	uint32_t curr = globalNextMeta;
	globalNextMeta++;
	return curr;
}

uint32_t getNextAddr (TableMetaEntry tableMeta){
	uint32_t curr = globalNextAddr;
	globalNextAddr = globalNextAddr + tableMeta.numRows;
	return curr;
}
*/
