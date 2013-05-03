

#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string.h>
#include <assert.h>
#include <stdint.h> 

#include "globalTypes.h"
#include "linkBlocks.h"

#include <vector>



using namespace std;

vector<uint32_t> schedule[MAX_NUM_CMDS];
vector<uint32_t> cmdInd;
uint32_t numScheds;

void print_schedule(){

  for ( uint32_t i = 0; i < numScheds; i++){
    printf("\nPrinting Schedule %d: -------------\n", i);
    
    
    for ( uint32_t j = 0; j < schedule[i].size(); j++ ){
      if ( j != 0){
	printf("======>\t");
      }
      else
	printf("\t");

      printf("CmdEntry %d: ",schedule[i][j]);
      uint32_t input_addr_0 = globalCmdEntryBuff[schedule[i][j]].table0Addr;
      uint32_t input_addr_1 = globalCmdEntryBuff[schedule[i][j]].table1Addr;
      uint32_t output_addr = globalCmdEntryBuff[schedule[i][j]].outputAddr;
      switch (globalCmdEntryBuff[schedule[i][j]].op){
      case SELECT:
	printf("SELECT{inputAddr: %d, outputAddr: %d}", input_addr_0, output_addr);
	break;
      case PROJECT:
	printf("PROJECT:{inputAddr: %d, outputAddr: %d}", input_addr_0, output_addr);
	break;
      case DEDUP:
	printf("DEDUP:{inputAddr: %d, outputAddr: %d}", input_addr_0, output_addr);
	break;
      case XPROD:
	printf("XPROD:{inputAddrs: %d and %d , outputAddr: %d}", input_addr_0, input_addr_1, output_addr);
	break;
      case UNION:
	printf("UNION:{inputAddrs: %d and %d , outputAddr: %d}", input_addr_0, input_addr_1, output_addr);
	break;
      case DIFFERENCE:
	printf("DIFFERENCE:{inputAddrs: %d and %d , outputAddr: %d}", input_addr_0, input_addr_1, output_addr);
	break;
      default:
	break;
      }
      
      printf("\n");
    }
  }
}


void scheduleCmds(){
  printf("Linking Blocks: enable data streaming between blocks????\n");

  //printf("here here");

  for (uint32_t i = 0; i < globalNCmds; i++)
    cmdInd.push_back(i);
  
  uint32_t ptr = 0;
  bool select_taken = false;
  bool project_taken = false;
  uint32_t tail_ind;
  uint32_t numChild;
  uint32_t new_tail_ind;
  bool dependence_found;

  while ( !cmdInd.empty() ){
    if ( schedule[ptr].empty() ){
      // a new schedule starts
      schedule[ptr].push_back(cmdInd.front());
      cmdInd.erase(cmdInd.begin());
      select_taken = false;
      project_taken = false;
    }
    else {
      //
      dependence_found = false;
      tail_ind = schedule[ptr][schedule[ptr].size()-1];
      numChild = 0;
      for ( uint32_t i  = 0; i < cmdInd.size(); i++){
	uint32_t ind = cmdInd[i];
	if ( globalCmdEntryBuff[tail_ind].outputAddr == globalCmdEntryBuff[ind].table1Addr)
	  numChild++;
	if ( globalCmdEntryBuff[tail_ind].outputAddr == globalCmdEntryBuff[ind].table0Addr){
	   numChild++;
	  if (globalCmdEntryBuff[ind].op == SELECT && !select_taken){
	    new_tail_ind = i;
	    select_taken = true;
	    dependence_found = true;
	  }
	  if (globalCmdEntryBuff[ind].op == PROJECT && !project_taken){
	    new_tail_ind = i;
	    project_taken = true;
	    dependence_found = true;
	  } 
	}
      }
      
      if ( numChild == 1 && dependence_found){
	schedule[ptr].push_back(cmdInd[new_tail_ind]);
	cmdInd.erase(cmdInd.begin()+new_tail_ind);
     }
      else{
	ptr++;
      }
      
    }
  }
  
  numScheds = ptr + 1;

  print_schedule();

}
