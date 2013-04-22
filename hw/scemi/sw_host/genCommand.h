#ifndef GEN_COMMAND_H
#define GEN_COMMAND_H


#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include <stdint.h> 
#include "SceMiHeaders.h"

uint32_t genCommand(const char *cmdFilePath, CmdEntry_sw *cmdEntryBuff);

void loadCommands(InportProxyT<BuffInit> & cmdBuffRequest, CmdEntry_sw *cmdEntryBuff);

void dumpCmdEntry(CmdEntry_sw cmdEntry);
void dumpTableMetas();



#endif //GEN_COMMAND_H
