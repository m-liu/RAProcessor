#ifndef GEN_COMMAND_H
#define GEN_COMMAND_H


#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include <stdint.h> 


uint32_t genCommand(const char *cmdFilePath, CmdEntry *cmdEntryBuff);

void dumpCmdEntry(CmdEntry cmdEntry);
void dumpTableMetas();



#endif //GEN_COMMAND_H
