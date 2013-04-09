#include "globalTypes.h"

#include <fstream>
#include <string>
#include <string.h>
#include <vector>
#include<dirent.h>
using namespace std;

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

bool parsecsv(const char *filename, const uint32_t tb_num, const uint32_t start_addr){
  //FILE *file = fopen(filename, "r");
  ifstream file(filename);
  string line;
  uint32_t numLines = 0;
  uint32_t mem_addr = start_addr;
  uint32_t numRows = 0;


  while (file.good()){
    getline(file,line);
    vector<string> tokens = getTokens(line);
    switch (numLines){
    case 0:
      if (tokens.size() > 0){
	strcpy(globalTableMeta[tb_num].tableName, tokens[0].c_str());
	//globalTableMeta[tb_num].numRows = strtoul(tokens[1].c_str(),NULL,10);
	//globalTableMeta[tb_num].numCols = strtoul(tokens[2].c_str(),NULL,10);
	globalTableMeta[tb_num].startAddr = mem_addr;
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
      if (tokens.size() >= globalTableMeta[tb_num].numCols){
	for ( uint32_t i = 0; i < globalTableMeta[tb_num].numCols; i++){
	  globalMem[mem_addr][i] = strtoul(tokens[i].c_str(), NULL, 10);
	}
	mem_addr++;
	numRows++;
      }
      else if (tokens.size() > 0){
	fprintf(stderr, "FAIL: Not Enough Data Fields");
	return false;
      }
      break;
    }
  }
  globalTableMeta[tb_num].numRows = numRows;
  return true;
}

void printTable(uint32_t tb_num){
  cout << "Table Name:\t" << globalTableMeta[tb_num].tableName;
  uint32_t nRows = globalTableMeta[tb_num].numRows;
  uint32_t nCols = globalTableMeta[tb_num].numCols;
  uint32_t addr_ptr = globalTableMeta[tb_num].startAddr;
  cout << "\nColumn Names:\t";  
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
}

bool parsecsv(){
  
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
	cout << "Parsing Table: " <<  entry->d_name << "\n";
	if (parsecsv(filename, globalNextMeta, globalNextAddr)){
	  cout << globalNextMeta << " " << globalNextAddr << endl; 
	  printTable(globalNextMeta);
	  globalNextAddr = globalNextAddr + globalTableMeta[globalNextMeta].numRows;
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

