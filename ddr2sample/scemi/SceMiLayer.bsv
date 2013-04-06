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
import GetPut::*;
import SceMi::*;

import DDR2::*;
import Dut::*;

module [SceMiModule] mkSceMiLayer(SceMiClockPortIfc clk_port, DDR2Client ifc);

    Dut dut <- buildDut(mkDut, clk_port);

    Empty request <- mkPutXactor(dut.request, clk_port);
    Empty response <- mkGetXactor(dut.response, clk_port);
    Empty holdback <- mkPutXactor(dut.holdback, clk_port);

    Empty shutdown <- mkShutdownXactor();

    DDR2Client ddr2 <- mkDDR2Xactor(dut.ddr2, clk_port);
    return ddr2;
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


