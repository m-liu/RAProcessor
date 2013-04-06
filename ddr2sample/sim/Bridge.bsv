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

import Connectable::*;
import SceMi::*;
import SceMiLayer::*;
import DefaultValue::*;

import XilinxDDR2::*;
import DDR2::*;

// Setup for SCE-MI over TCP
SceMiLinkType lt = TCP;

// mkSceMiLayerWrapper hooks up the mkSceMiLayer to a simulated DDR2.
module [SceMiModule] mkSceMiLayerWrapper (Empty);

    SceMiClockConfiguration conf = defaultValue;
    SceMiClockPortIfc clk_port <- mkSceMiClockPort(conf);

    DDR2_User server <- mkDDR2Simulator();
    DDR2Client m <- mkSceMiLayer(clk_port);

    mkConnection(m, server);
endmodule

(* synthesize *)
module mkBridge ();

   Empty scemi <- buildSceMi(mkSceMiLayerWrapper, lt);

endmodule: mkBridge

