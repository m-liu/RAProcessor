#ifndef TABLE_PARSER_H
#define TABLE_PARSER_H

#include <fstream>
#include <string>
#include <string.h>
#include <vector>

#include "globalTypes.h"

#include "SceMiHeaders.h"

//void printTable(uint32_t tb_num);


void dumpMemory(InportProxyT<ROW_REQ> &rowReq, OutportQueueT<ROW_BURST> &rdBurst);
void loadChunk(uint32_t start_addr, uint32_t numRows, InportProxyT<ROW_REQ> &rowReq, InportProxyT<ROW_BURST> &wrBurst);
bool parsecsv(InportProxyT<ROW_REQ> &rowReq, InportProxyT<ROW_BURST> &wrBurst);
bool parsecsv(const char *filename, const uint32_t tb_num, const uint32_t start_addr,InportProxyT<ROW_REQ> &rowReq, InportProxyT<ROW_BURST> &wrBurst);

#endif
