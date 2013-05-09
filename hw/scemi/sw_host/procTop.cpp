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

  
  globalNCmds = genCommand(cmdIn, globalCmdEntryBuff);
  scheduleCmds();
  loadCommands(cmdBuffRequest, globalCmdEntryBuff);

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
  
  //wait for ack from HW
  uint32_t nRows = getRowAck.getMessage();
  //uint32_t nRow2 = getRowAck.getMessage();
  printf("Hardware ack received: nRows=%d", nRows);
  
  /*
  printf("command dump AFTER execution:\n");
  for (uint32_t i=0; i<globalNCmds; i++){
    dumpCmdEntry(globalCmdEntryBuff[i]);
  }
  dumpTableMetas();
  */
  
  printf("\n************************************\n");
  printf("Final table values:\n");



  dumpMemory(rowReq, rdBurst);
  /*
  for (uint32_t i=0; i<globalNextMeta; i++){
    printTable(i);
  }
  */

  /****Shutting down SceMi****/
  shutdown.blocking_send_finish();
  scemi_service_thread->stop();
  scemi_service_thread->join();
  SceMi::Shutdown(sceMi);

  return 0;
}
