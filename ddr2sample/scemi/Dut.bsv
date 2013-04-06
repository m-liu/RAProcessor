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

import FIFO::*;
import GetPut::*;
import ClientServer::*;

import DDR2::*;

// Sample Dut which interacts with DDR2
// The dut takes raw ddr2 requests from the testbench and forwards them to the
// DDR2. It also forwards responses from the DDR2 back to the test bench.
//
// Designs which wish to use the DDR2 should implement a DDR2Client interface
// which is connected to the DDR2 controller in the Bridge.
//
// See ddr/DDR2.bsv for the definition of DDR2Request and DDR2Response.

interface Dut;
    // Application interface.
    // Accepts DDR requests from the testbench,
    // sends responses back to the testbench.
    interface Put#(DDR2Request) request;
    interface Get#(DDR2Response) response;

    // holdback causes responses not to be gotten while true. When holdback is
    // set to false, responses will then be gotten from the DDR.
    // This gives us a way to test the buffering concerns we have.
    interface Put#(Bool) holdback;

    // DDR2Client interface. All duts which want to use DDR2 on FPGA should
    // implement this interface (which will be connected to the actual DDR2
    // controller).
    interface DDR2Client ddr2;
endinterface

module [Module] mkDut(Dut);

    Reg#(Bool) hold <- mkReg(False);

    FIFO#(DDR2Request) requests <- mkSizedFIFO(64);
    FIFO#(DDR2Response) responses <- mkSizedFIFO(64);

    interface Put request = toPut(requests);
    interface Get response = toGet(responses);
    interface Put holdback = toPut(asReg(hold));

    interface Client ddr2;
        interface Get request = toGet(requests);
        interface Put response;
           method Action put(DDR2Response x) if (!hold);
              responses.enq(x);
           endmethod
        endinterface
    endinterface

endmodule

