#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include "SceMiHeaders.h"


int main(int argc, char* argv[]){
  
  // Scemi
  int sceMiVersion = SceMi::Version( SCEMI_VERSION_STRING );
  SceMiParameters params("scemi.params");
  SceMi *sceMi = SceMi::Init(sceMiVersion, &params);

  // Initialize the SceMi ports
  InportProxyT<ROW_REQ> rowReq("", "scemi_m_rowReq_put_inport", sceMi);
  OutportQueueT<ROW_BURST> rdBurst("", "scemi_m_rdBurst_get_outport", sceMi);
  InportProxyT<ROW_BURST> wrBurst("", "scemi_m_wrBurst_put_inport", sceMi);
  ShutdownXactor shutdown("", "scemi_m_shutdown", sceMi);

  // Service SceMi requests
  SceMiServiceThread *scemi_service_thread = new SceMiServiceThread(sceMi);

  ROW_REQ request;
  Op wr_op;
  wr_op.m_val = Op::e_WRITE;

  request.m_op = wr_op;
  request.m_reqSrc = 0;
  request.m_numRows = 1;
  request.m_rowAddr = 0;
  rowReq.sendMessage(request);

  
  for (uint32_t i = 0; i < 32; i++){
    printf("Writing Col_data %d\n", i+16);
    wrBurst.sendMessage(i+16);
  }

  wr_op.m_val = Op::e_READ;
  request.m_op = wr_op;
  request.m_reqSrc = 0;
  request.m_numRows = 1;
  request.m_rowAddr = 0;
  rowReq.sendMessage(request);
  
  for ( uint32_t i = 0; i < 32; i++){
    ROW_BURST response = rdBurst.getMessage();
    uint32_t resp = response;
    printf("Got Col_data %i\n", resp);
  }


  shutdown.blocking_send_finish();
  scemi_service_thread->stop();
  scemi_service_thread->join();
  SceMi::Shutdown(sceMi);
}