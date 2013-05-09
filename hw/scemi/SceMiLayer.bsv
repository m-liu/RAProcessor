// The MIT License

// Copyright (c) 2010, 2011 Massachusetts Institute of Technology

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Author: Richard Uhler ruhler@mit.edu

import Clocks::*;
import Connectable::*;
import DefaultValue::*;
import ClientServer::*;
import GetPut::*;
import SceMi::*;

import DDR2::*;
import procTop::*;
import RowMarshaller::*;
import CmdBufferTypes::*;
import ResetXactor::*;

//import Dut::*;

typedef RAProcessor Dut;

module [SceMiModule] mkSceMiLayer(SceMiClockPortIfc clk_port, DDR2Client ifc);

    //Dut dut <- buildDut(mkDut, clk_port);
   Dut dut <- buildDut(mkRAProcessor, clk_port);
   //Dut dut <- buildDutWithSoftReset(mkRAProcessor, clk_port);
   
   /* 
   Empty request <- mkPutXactor(dut.request, clk_port);
    Empty response <- mkGetXactor(dut.response, clk_port);
    Empty holdback <- mkPutXactor(dut.holdback, clk_port);
   */
   Empty rowReq <- mkrowReqXactor(dut, clk_port);
   Empty rdBurst <- mkrdBurstXactor(dut, clk_port);
   Empty wrBurst <- mkwrBurstXactor(dut, clk_port);
   Empty cmdBuffRequest <- mkPutXactor(dut.cmdBuffInit.request,  clk_port);
   Empty loadCmdBuffSize <- mkPutXactor(dut.loadCmdBuffSize, clk_port);

   Empty getRowAck <- mkGetXactor(dut.getRowAck, clk_port);
   
    Empty shutdown <- mkShutdownXactor();

    DDR2Client ddr2 <- mkDDR2Xactor(dut.ddr2, clk_port);
    return ddr2;
endmodule

module [SceMiModule] mkrowReqXactor#(RAProcessor proc, SceMiClockPortIfc clk_port ) (Empty);

    Put#(RowReq) req = interface Put;
        method Action put(RowReq x) = proc.hostDataIO.rowReq(x);
    endinterface;

    Empty put <- mkPutXactor(req, clk_port);
endmodule

module [SceMiModule] mkrdBurstXactor#(RAProcessor proc, SceMiClockPortIfc clk_port ) (Empty);

    Get#(RowBurst) resp = interface Get;
        method ActionValue#(RowBurst) get = proc.hostDataIO.readResp();
    endinterface;

    Empty get <- mkGetXactor(resp, clk_port);
endmodule

module [SceMiModule] mkwrBurstXactor#(RAProcessor proc, SceMiClockPortIfc clk_port ) (Empty);

    Put#(RowBurst) req = interface Put;
        method Action put(RowBurst x) = proc.hostDataIO.writeData(x);
    endinterface;

    Empty put <- mkPutXactor(req, clk_port);
endmodule

// mkDDr2Xactor Brings a DDR2Client from the controlled clock domain out into
// the uncontrolled clock domain.
module [SceMiModule] mkDDR2Xactor#(DDR2Client ddr2, SceMiClockPortIfc clk_port) (DDR2Client);

    // Access the controlled clock and reset
    Clock cclock = clk_port.cclock;
    Reset creset = clk_port.creset;

    // Access the uncontrolled clock and reset
    Clock uclock <- sceMiGetUClock;
    Reset ureset <- sceMiGetUReset;

    DDR2Client ifc <- mkDDR2ClientSync(ddr2, cclock, creset, uclock, ureset);
    return ifc;

endmodule


