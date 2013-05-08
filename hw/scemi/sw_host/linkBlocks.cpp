

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

vector<uint32_t> cmdInd;

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
  printf("Linking Blocks: enable data streaming between blocks\n");

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


void handle_clause(CmdEntry &cmdEntry, CmdEntry_sw const &cmdEntry_sw, uint32_t const dest, uint32_t const src ){
  //**********loading clauses******
  switch ( (cmdEntry_sw.clauses)[src].clauseType ){
  case COL_COL:
    ((cmdEntry.m_clauses)[dest]).m_clauseType.m_val = ClauseType::e_COL_COL;
    break;
  case COL_VAL:
    ((cmdEntry.m_clauses)[dest]).m_clauseType.m_val = ClauseType::e_COL_VAL;
    break;
  default:
    break;
  }
  (cmdEntry.m_clauses)[dest].m_colOffset0 = (cmdEntry_sw.clauses)[src].colOffset0;
  (cmdEntry.m_clauses)[dest].m_colOffset1 = (cmdEntry_sw.clauses)[src].colOffset1;
  switch ((cmdEntry_sw.clauses)[src].op){
  case EQ:
    ((cmdEntry.m_clauses)[dest]).m_op.m_val = CompOp::e_EQ;
    break;	
  case LT:
    ((cmdEntry.m_clauses)[dest]).m_op.m_val = CompOp::e_LT;
    break;
  case LE:
    ((cmdEntry.m_clauses)[dest]).m_op.m_val = CompOp::e_LE;
    break;
  case GT:
    ((cmdEntry.m_clauses)[dest]).m_op.m_val = CompOp::e_GT;
    break;
  case GE:
    ((cmdEntry.m_clauses)[dest]).m_op.m_val = CompOp::e_GE;
    break;
  case NE:
    ((cmdEntry.m_clauses)[dest]).m_op.m_val = CompOp::e_NE;
    break;
  default:
    break;
  }
  (cmdEntry.m_clauses)[dest].m_val = (cmdEntry_sw.clauses)[src].val;
}



/******load commands on to fpga BRAM thru SceMi*******/
void loadCommands(InportProxyT<BuffInit> & cmdBuffRequest, CmdEntry_sw *cmdEntryBuff){
  BuffInit msg;
  
  BuffInitLoad msg_ld;

  CmdEntry cmdEntry;
  
  uint32_t buff_ind = 0;

  for ( uint32_t i = 0; i < numScheds; i++){
    for ( uint32_t j = 0; j < schedule[i].size(); j++ ){
      uint32_t ind = schedule[i][j];
      //printf("loading cmdEntry %d\n",ind);
      if ( j == 0 ) {
	cmdEntry.m_inputSrc.m_val = DataLoc::e_MEMORY;
      }
      else {
	switch ( cmdEntryBuff[schedule[i][j-1]].op ){
	case SELECT:
	  cmdEntry.m_inputSrc.m_val = DataLoc::e_SELECT;
	  break;
	case PROJECT:
	  cmdEntry.m_inputSrc.m_val = DataLoc::e_PROJECT;
	  break;
	case UNION:
	  cmdEntry.m_inputSrc.m_val = DataLoc::e_UNION;
	  break;
	case DIFFERENCE:
	  cmdEntry.m_inputSrc.m_val = DataLoc::e_DIFFERENCE;
	  break;
	case XPROD:
	  cmdEntry.m_inputSrc.m_val = DataLoc::e_XPROD;
	  break;
	case DEDUP:
	  cmdEntry.m_inputSrc.m_val = DataLoc::e_DEDUP;
	  break;
	}
      }
      
      if ( j == schedule[i].size() - 1 ) {
	cmdEntry.m_outputDest.m_val = DataLoc::e_MEMORY;
      }
      else {
	switch ( cmdEntryBuff[schedule[i][j+1]].op ){
	case SELECT:
	  cmdEntry.m_outputDest.m_val = DataLoc::e_SELECT;
	  break;
	case PROJECT:
	  cmdEntry.m_outputDest.m_val = DataLoc::e_PROJECT;
	  break;
	case UNION:
	  cmdEntry.m_outputDest.m_val = DataLoc::e_UNION;
	  break;
	case DIFFERENCE:
	  cmdEntry.m_outputDest.m_val = DataLoc::e_DIFFERENCE;
	  break;
	case XPROD:
	  cmdEntry.m_outputDest.m_val = DataLoc::e_XPROD;
	  break;
	case DEDUP:
	  cmdEntry.m_outputDest.m_val = DataLoc::e_DEDUP;
	  break;
	}
      }

      
      CmdEntry_sw cmdEntry_sw = cmdEntryBuff[ind];
      cmdEntry.m_table0Addr = cmdEntry_sw.table0Addr;
      cmdEntry.m_table0numRows = cmdEntry_sw.table0numRows;
      cmdEntry.m_table0numCols = cmdEntry_sw.table0numCols;
      cmdEntry.m_outputAddr = cmdEntry_sw.outputAddr;
      //cmdEntry.m_numClauses = cmdEntry_sw.numClauses;
      cmdEntry.m_colProjectMask = cmdEntry_sw.colProjectMask;
      cmdEntry.m_projNumCols = cmdEntry_sw.projNumCols;
      cmdEntry.m_table1Addr = cmdEntry_sw.table1Addr;
      cmdEntry.m_table1numRows = cmdEntry_sw.table1numRows;
      cmdEntry.m_table1numCols = cmdEntry_sw.table1numCols;
    
      switch (cmdEntry_sw.op){
      case SELECT:
	cmdEntry.m_op.m_val = CmdOp::e_SELECT;
      
	uint32_t or_loc[MAX_CLAUSES/4-1];
	uint32_t and_loc[3*MAX_CLAUSES/4];
	//uint32_t next_and_blk[MAX_CLAUSES/4-1];
      
	// initializing and/or mask locations
	for (uint32_t ind_or = 0,ind_and = 0, k = 1; k < MAX_CLAUSES; k++){
	  if ( k % 4 == 0 )
	    or_loc[ind_or++] = k;
	
	  else
	    and_loc[ind_and++] = k;
	}
	
	/*
	printf("\nor locations:\n");
	for ( uint32_t k = 0; k < MAX_CLAUSES/4-1; k++)
	  printf("%d\t",or_loc[k]);
      
	printf("\nand locations:\n");
	for ( uint32_t k = 0; k < 3*MAX_CLAUSES/4; k++)
	  printf("%d\t",and_loc[k]);
	printf("\n");
	*/
      
	uint16_t validClauseMask;
      
	uint32_t ind_or, ind_and;
	validClauseMask = 0;
	ind_or = ind_and = 0;
      
	/*do the first clause*/
	if ( cmdEntry_sw.numClauses > 0){
	  handle_clause(cmdEntry, cmdEntry_sw, 0, 0);
	  validClauseMask = 1;
	}
      
	/*do the rest of the clause*/
	for ( uint32_t k = 0; k < cmdEntry_sw.numClauses - 1; k++){
	  //*****load clause_cons*****
	  switch ( (cmdEntry_sw.con)[k] ){
	  case AND:
	    //(cmdEntry.m_con)[k].m_val = ClauseCon::e_AND;
	    assert(ind_and < 3*MAX_CLAUSES/4);
	    validClauseMask = validClauseMask + (1 << (and_loc[ind_and]));
	    handle_clause(cmdEntry, cmdEntry_sw, and_loc[ind_and++], k+1);
	    break;
	  case OR:
	    //(cmdEntry.m_con)[k].m_val = ClauseCon::e_OR;
	    assert(ind_or < MAX_CLAUSES/4-1);
	    ind_and = (ind_and + 3) - (ind_and+3)%3;
	    validClauseMask = validClauseMask + (1 << (or_loc[ind_or]));
	    handle_clause(cmdEntry, cmdEntry_sw, or_loc[ind_or++], k+1);
	    break;
	  default:
	    break;
	  }
	}
	//printf("validClauseMask: %x\n", validClauseMask);
	cmdEntry.m_validClauseMask = validClauseMask;
	break;
      case PROJECT:
	cmdEntry.m_op.m_val = CmdOp::e_PROJECT;
	break;
      case UNION:
	cmdEntry.m_op.m_val = CmdOp::e_UNION;
	break;
      case DIFFERENCE:
	cmdEntry.m_op.m_val = CmdOp::e_DIFFERENCE;
	break;
      case XPROD:
	cmdEntry.m_op.m_val = CmdOp::e_XPROD;
	break;
      case DEDUP:
	cmdEntry.m_op.m_val = CmdOp::e_DEDUP;
      default:
	break;
      }
      msg_ld.m_index  = buff_ind++;
      msg_ld.m_data = cmdEntry;
      msg.the_tag = BuffInit::tag_InitLoad;
      msg.m_InitLoad = msg_ld;
      cmdBuffRequest.sendMessage(msg);
    }
  }
  
  /**finish**/
  msg.the_tag = BuffInit::tag_InitDone;
  cmdBuffRequest.sendMessage(msg);

}
