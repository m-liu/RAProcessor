#include <iostream>     
#include <unistd.h>     
#include <cmath>        
#include <cstdio>       
#include <cstdlib>      
#include <string.h>     
#include <stdint.h>     
                        
#include "globalTypes.h"
#include "tableParser.h"
#include "genCommand.h" 
#include "linkBlocks.h"
//#include "procModel.h"

#include "SceMiHeaders.h"
//#include "ResetXactor.h"
#define FPGA_CLK 50e6



int main(int argc, char* argv[]){
  
  /****Booting Up Scemi****/
  // Scemi
  int sceMiVersion = SceMi::Version( SCEMI_VERSION_STRING );
  SceMiParameters params("scemi.params");
  SceMi *sceMi = SceMi::Init(sceMiVersion, &params);

  // Initialize the SceMi ports
  InportProxyT<RowReq> rowReq("", "scemi_m_rowReq_put_inport", sceMi);
  OutportQueueT<RowBurst> rdBurst("", "scemi_m_rdBurst_get_outport", sceMi);
  InportProxyT<RowBurst> wrBurst("", "scemi_m_wrBurst_put_inport", sceMi);
  InportProxyT<BuffInit> cmdBuffRequest("","scemi_m_cmdBuffRequest_inport", sceMi);
  InportProxyT<Index> loadCmdBuffSize("","scemi_m_loadCmdBuffSize_inport", sceMi);
  OutportQueueT<RowAddr> getRowAck("", "scemi_m_getRowAck_outport", sceMi);
  OutportQueueT<Cycles> getCycles("", "scemi_m_getCycles_outport", sceMi);
  ShutdownXactor shutdown("", "scemi_m_shutdown", sceMi);

  // Initialize the reset port.
  //ResetXactor reset("", "scemi_m", sceMi);
  

  // Service SceMi requests
  SceMiServiceThread *scemi_service_thread = new SceMiServiceThread(sceMi);

  // Reset the dut.
  //reset.reset();

  //sleep(5);

  /****Parsing Tables/Command*****/
  
  if (argc < 2) {
    fprintf(stderr, "\nInput a command file\n");
    return 1;
  }

  char* cmdIn = argv[1];

  printf("\nReading the CSV files in directory ./input/.........\n");
  if ( !parsecsv(rowReq, wrBurst) ) {
    fprintf(stderr, "\nMemInit Unsuccessful\n");
  }
  else{
    printf("\nCSV files Read Successful, Memory Initialized!...........\n\n");
  }
  fflush(stdout);

  bool bypass_b;
  
    //printf("Enable Passing Between Blocks?(y/n): ");
    //scanf("%s", &bypass_c);
	
    if ( argc==3 ) {
      bypass_b = false;
      printf("\nPassing Between Blocks Disabled!\n");
    }
    else {
      bypass_b = true;
      printf("\nPassing Between Blocks Enabled!\n");
    }
    
  fflush(stdout);
  
  globalNCmds = genCommand(cmdIn, globalCmdEntryBuff);
  scheduleCmds();
  loadCommands(cmdBuffRequest, globalCmdEntryBuff, bypass_b);

  //printf("num of commands: %d", globalNCmds);
  loadCmdBuffSize.sendMessage(globalNCmds);
  //sleep(1);
  /*
  printf("command dump BEFORE execution:\n");
  for (uint32_t i=0; i<globalNCmds; i++){
    dumpCmdEntry(globalCmdEntryBuff[i]);
  }
  
  //runProcModel();
  */
  //sleep(5);
  //wait for ack from HW
  uint32_t nRows = getRowAck.getMessage();
  //uint32_t nRow2 = getRowAck.getMessage();


  
  printf("Hardware ack received: nRows=%d", nRows);

  
  fflush(stdout);


  //fflush(stdout);
  /*
  printf("command dump AFTER execution:\n");
  for (uint32_t i=0; i<globalNCmds; i++){
    dumpCmdEntry(globalCmdEntryBuff[i]);
  }
  dumpTableMetas();
  */
  /*
  printf("\n************************************\n");
  printf("Final table:\n");

  printTable(globalNextMeta-1, rowReq, rdBurst);
  */
  
  printf("\n************************************\n");
  printf("Final table values:\n");



  dumpMemory(rowReq, rdBurst);
  /*
  for (uint32_t i=0; i<globalNextMeta; i++){
    printTable(i);
  }
  */
  fflush(stdout);

  printf("\n***********************************\n");
    if ( !bypass_b ) {
      printf("\nPassing Between Blocks Disabled!\n");
    }
    else {
      printf("\nPassing Between Blocks Enabled!\n");
    }
    
  printf("Printing Benchmark Counter\n");

  for(int i=0; i < globalNCmds+1; i++) {
	  Cycles nCycles = getCycles.getMessage();
	  uint64_t cycles = nCycles.m_tpl_2;

	  
	  switch ( nCycles.m_tpl_1.m_val ){
	  case CycleSrc::e_CONTROLLER:
		printf("Controller: %ld cycles or %e seconds\n", cycles, (double)cycles/FPGA_CLK);
		break;
	  case CycleSrc::e_SELECT:
		printf("Select: %ld cycles or %e seconds\n", cycles, (double)cycles/FPGA_CLK);
		break;
	  case CycleSrc::e_PROJECT:
		printf("Project: %ld cycles or %e seconds\n", cycles, (double)cycles/FPGA_CLK);
		break;
	  case CycleSrc::e_UNION:
		printf("Union: %ld cycles or %e seconds\n", cycles, (double)cycles/FPGA_CLK);
		break;
	  case CycleSrc::e_DIFFERENCE:
		printf("Difference: %ld cycles or %e seconds\n", cycles, (double)cycles/FPGA_CLK);
		break;
	  case CycleSrc::e_XPROD:
		printf("Xprod: %ld cycles or %e seconds\n", cycles, (double)cycles/FPGA_CLK);
		break;
	  case CycleSrc::e_DEDUP:
		printf("Dedup: %ld cycles or %e seconds\n", cycles, (double)cycles/FPGA_CLK);
		break;
	  default:
		break;
	  }
  
  	  fflush(stdout);
	}
  /****Shutting down SceMi****/
  shutdown.blocking_send_finish();
  scemi_service_thread->stop();
  scemi_service_thread->join();
  SceMi::Shutdown(sceMi);

  return 0;
}
