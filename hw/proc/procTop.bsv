//top BSV file of RA processor

import RowMarshaller::*;
import XilinxDDR2::*;
import DDR2::*;
import Connectable::*;

interface RAProcessor;
   interface ROW_ACCESS_IFC hostDataIO;
   interface DDR2Client ddr2;
   //interface HostCommand;
endinterface

module [Module] mkRAProcessor(RAProcessor);
   ROW_MARSHALLER_IFC rowMarshaller <- mkRowMarshaller();
   
   interface hostDataIO = rowMarshaller.rowAccesses[0];
   
   interface ddr2 = rowMarshaller.ddrMem;
   //interface HostCommand;
   //endinterface
      
endmodule