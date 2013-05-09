//#include "globalTypes.h"
#include "tableParser.h"

#include <fstream>
#include <string>
#include <string.h>
#include <vector>
#include <dirent.h>
using namespace std;


#define MAX_ROWS_CHUNK 128
uint32_t rowChunk[MAX_ROWS_CHUNK][MAX_COLS];

vector<string> getTokens(string const &in){
  const size_t len = in.length();
  size_t i = 0;
  vector<string> container;

  while (i < len){
    // Eat leading whitespace
    i = in.find_first_not_of(" \t\n", i);
    if (i == string::npos)
      break;   // Nothing left but white space

    // Find the end of the token
    size_t j = in.find_first_of(",", i);

    // Push token
    if (j == string::npos)
      {
	//std::cout << in.substr(i,j) << std::endl;
	container.push_back(in.substr(i,j));
	break;
      }
    else{
      //std::cout << in.substr(i,j) << std::endl;
      container.push_back(in.substr(i, j-i));
    }
    // Set up for next loop
    i = j + 1;
  }
  return container;
}
/*
void loadChunk(uint32_t start_addr, uint32_t rowOffset,  uint32_t numRows, uint32_t numCols, InportProxyT<RowReq> &rowReq, InportProxyT<RowBurst> &wrBurst){
  RowReq request;
  
  MemOp wr_op;
  wr_op.m_val = MemOp::e_WRITE;
  
  RowReqType reqType;
  reqType.m_val = RowReqType::e_REQ_NROWS;
  
  request.m_tableAddr = start_addr;
  request.m_rowOffset = rowOffset;
  request.m_numRows = numRows;
  request.m_numCols = numCols;
  request.m_reqSrc = 0;
  request.m_reqType = reqType;
  request.m_op = wr_op;
  rowReq.sendMessage(request);

  printf("\nWriting Chunk");
  for (uint32_t i = 0; i < numRows; i++){
    printf("\n");
    for (uint32_t j = 0; j < numCols; j++){
      printf("%d\t",rowChunk[i][j]);
      // if ( j < numCols){
      wrBurst.sendMessage(rowChunk[i][j]);
      //}
      // else{
      //wrBurst.sendMessage(0);
      //}
    }
  }
}
*/

bool parsecsv(const char *filename, const uint32_t tb_num, const uint32_t start_addr,InportProxyT<RowReq> &rowReq, InportProxyT<RowBurst> &wrBurst){
  //FILE *file = fopen(filename, "r");
  ifstream file(filename);
  string line;
  uint32_t numLines = 0;
  //uint32_t rowOffset = 0;
  //uint32_t mem_addr = start_addr;
  uint32_t numRows = 0;
  //uint32_t chunk_ptr = 0;

  RowReq request;
  
  MemOp wr_op;
  wr_op.m_val = MemOp::e_WRITE;
  
  RowReqType reqType;
  reqType.m_val = RowReqType::e_REQ_ALLROWS;
  
  request.m_tableAddr = start_addr;
  request.m_rowOffset = 0;
  //request.m_numRows = numRows;
  //request.m_numCols = numCols;
  request.m_reqSrc = 0;
  request.m_reqType = reqType;
  request.m_op = wr_op;
  rowReq.sendMessage(request);

  while (file.good()){
    getline(file,line);
    vector<string> tokens = getTokens(line);
    switch (numLines){
    case 0:
      if (tokens.size() > 0){
	strcpy(globalTableMeta[tb_num].tableName, tokens[0].c_str());
	//globalTableMeta[tb_num].numRows = strtoul(tokens[1].c_str(),NULL,10);
	//globalTableMeta[tb_num].numCols = strtoul(tokens[2].c_str(),NULL,10);
	globalTableMeta[tb_num].startAddr = start_addr;
	numLines++;
      }
      break;
    case 1:
      if (tokens.size() > 0){
	globalTableMeta[tb_num].numCols = tokens.size();
	for ( uint32_t i = 0; i < tokens.size(); i++)
	  strcpy(globalTableMeta[tb_num].colNames[i], tokens[i].c_str());
	numLines++;
      }
      break;
    default:
      /*
      if (chunk_ptr == MAX_ROWS_CHUNK){
	loadChunk(mem_addr,rowOffset, chunk_ptr, globalTableMeta[tb_num].numCols, rowReq, wrBurst);
	chunk_ptr = 0;
	rowOffset += MAX_ROWS_CHUNK;
      }
      */
      if (tokens.size() >= globalTableMeta[tb_num].numCols){
	for ( uint32_t i = 0; i < globalTableMeta[tb_num].numCols; i++){
	  //rowChunk[chunk_ptr][i] = strtoul(tokens[i].c_str(), NULL, 10);
	  wrBurst.sendMessage(strtoul(tokens[i].c_str(), NULL, 10));
	}
	//chunk_ptr++;
	//mem_addr++;
	numRows++;
      }
      else if (tokens.size() > 0){
	fprintf(stderr, "FAIL: Not Enough Data Fields");
	return false;
      }
      break;
    }
  }
  //loadChunk(mem_addr, rowOffset, chunk_ptr,globalTableMeta[tb_num].numCols, rowReq, wrBurst);
  wrBurst.sendMessage(-1);
  globalTableMeta[tb_num].numRows = numRows;
  /*
  RowReq request;
  
  MemOp wr_op;
  wr_op.m_val = MemOp::e_WRITE;
  
  RowReqType reqType;
  reqType.m_val = RowReqType::e_REQ_EOT;
  
  request.m_tableAddr = mem_addr;
  request.m_rowOffset = numRows;
  request.m_numRows = 8;
  request.m_numCols = globalTableMeta[tb_num].numCols;
  request.m_reqSrc = 0;
  request.m_reqType = reqType;
  request.m_op = wr_op;
  rowReq.sendMessage(request);
  */
  
  return true;
}
/*
  void printTable(uint32_t tb_num){
  cout << "Table Name:\t" << globalTableMeta[tb_num].tableName;
  uint32_t nRows = globalTableMeta[tb_num].numRows;
  uint32_t nCols = globalTableMeta[tb_num].numCols;
  uint32_t addr_ptr = globalTableMeta[tb_num].startAddr;
  cout << "\nColumn Names:\n";  
  for (uint32_t i = 0; i < nCols; i++){
  cout << globalTableMeta[tb_num].colNames[i] << "\t";
  }
  cout << "\nData:\n";
  for (uint32_t i = 0; i < nRows; i++){
  for (uint32_t j = 0; j < nCols; j++){
  cout << globalMem[addr_ptr+i][j] <<"\t";
  }
  cout << endl;
  }
  cout << "------" << endl;
  }
*/

void printTable(uint32_t tb_num,  InportProxyT<RowReq> &rowReq, OutportQueueT<RowBurst> &rdBurst){
  RowReq request;
  
  MemOp wr_op;
  wr_op.m_val = MemOp::e_READ;
  
  RowReqType reqType;
  reqType.m_val = RowReqType::e_REQ_ALLROWS;

  cout << "Table Name:\t" << globalTableMeta[tb_num].tableName;
  uint32_t nCols = globalTableMeta[tb_num].numCols;
  uint32_t nRowsMax = globalTableMeta[tb_num].numRows+32; //for printing purposes when table is empty
  uint32_t addr_ptr = globalTableMeta[tb_num].startAddr;
  printf("\tTable Addr: %x",addr_ptr);
  
  request.m_tableAddr = addr_ptr;
  request.m_rowOffset = 0;
  request.m_numCols = nCols;
  request.m_reqSrc = 0;
  request.m_reqType = reqType;
  request.m_op = wr_op;
  rowReq.sendMessage(request);
    
  cout << "\nColumn Names:\n";  
  for (uint32_t i = 0; i < nCols; i++){
    cout << globalTableMeta[tb_num].colNames[i] << "\t";
  }
  cout << "\nData:\n";
  
  uint32_t resp = 0;
  uint32_t colCnt = 0;
  uint32_t rowCnt = 0;
  // while (true) {
  while ( (resp != 0xFFFFFFFF) && (rowCnt < nRowsMax) ){
    //printf("here\n");
      //fflush(stdout);
    resp = rdBurst.getMessage();
    
    if (colCnt == nCols){
      colCnt = 0;
      rowCnt++;
      cout << endl;
      }
    
      cout << resp << "\t";
      colCnt++;
    }
  
  printf("\n\n");
  if (rowCnt == nRowsMax) {
    printf("Note: max nrows reached, stopped printing\n");
  }
  //printf("\none table done\n\n");
    
}

void dumpMemory(InportProxyT<RowReq> &rowReq, OutportQueueT<RowBurst> &rdBurst){
  
  
  for (uint32_t tb_num = 0; tb_num < globalNextMeta; tb_num++){
    printTable(tb_num, rowReq, rdBurst);
  }
}



bool parsecsv(InportProxyT<RowReq> &rowReq, InportProxyT<RowBurst> &wrBurst){
  
  DIR *pDIR;
  struct dirent *entry;
  char input_dir[] = "./input/";
  char filename[MAX_CHARS];
  if( (pDIR=opendir(input_dir)) ){
    while((entry = readdir(pDIR))){
      //uint32_t str_len = strlen(entry->d_name);
      if( strstr(entry->d_name,".csv") != NULL ){
	strcpy(filename, input_dir);
	strcat(filename, entry->d_name);
	cout << "\nParsing Table: " <<  entry->d_name;
	if (parsecsv(filename, globalNextMeta, globalNextAddr, rowReq, wrBurst)){
	  //cout << globalNextMeta << " " << globalNextAddr << endl; 
	  //printTable(globalNextMeta);
	  globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows + 8;
	  globalNextMeta++;
	}
	else{
	  return false;
	}	
      }
    }
    closedir(pDIR);
  }
  
  return true;
}

