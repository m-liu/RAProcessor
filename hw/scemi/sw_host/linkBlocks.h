#ifndef LINK_BLOCKS_H
#define LINK_BLOCKS_H


#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include <stdint.h> 
#include "SceMiHeaders.h"


void scheduleCmds();
void loadCommands(InportProxyT<BuffInit> & cmdBuffRequest, CmdEntry_sw *cmdEntryBuff, bool byPass);

//void dumpCmdEntry(CmdEntry cmdEntry);
//void dumpTableMetas();



#endif //LINK_BLOCKS_H
