#ifndef TABLE_PARSER_H
#define TABLE_PARSER_H

#include <fstream>
#include <string>
#include <string.h>
#include <vector>

#include "globalTypes.h"

#include "SceMiHeaders.h"

//void printTable(uint32_t tb_num);


void printTable(uint32_t tb_num,  InportProxyT<RowReq> &rowReq, OutportQueueT<RowBurst> &rdBurst);
void dumpMemory(InportProxyT<RowReq> &rowReq, OutportQueueT<RowBurst> &rdBurst);
void loadChunk(uint32_t start_addr, uint32_t numRows, InportProxyT<RowReq> &rowReq, InportProxyT<RowBurst> &wrBurst);
bool parsecsv(InportProxyT<RowReq> &rowReq, InportProxyT<RowBurst> &wrBurst);
bool parsecsv(const char *filename, const uint32_t tb_num, const uint32_t start_addr,InportProxyT<RowReq> &rowReq, InportProxyT<RowBurst> &wrBurst);

#endif
