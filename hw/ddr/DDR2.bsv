// The MIT License

// Copyright (c) 2011 Massachusetts Institute of Technology

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

import GetPut::*;
import FIFO::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import Counter::*;
import RegFile::*;
import Vector::*;

import XilinxDDR2::*;

typedef Bit#(31) DDR2Address;
typedef Bit#(256) DDR2Data;

// DDR2 Request
// Used for both reads and writes.
//
// To perform a read:
//  writeen should be 0
//  address contains the address to read from
//  datain is ignored.

// To perform a write:
//  writeen should be 'hFFFFFFFF (to write all bytes, or something else
//      nonzero to only write some of the bytes).
//  address contains the address to write to
//  datain contains the data to be written.
typedef struct {
    // writeen: Enable writing.
    // Set the ith bit of writeen to 1 to write the ith byte of datain to the
    // ith byte of data at the given address.
    // If writeen is 0, this is a read request, and a response is returned.
    // If writeen is not 0, this is a write request, and no response is
    // returned.
    Bit#(32) writeen;

    // Address to read to or write from.
    // The DDR2 is 64 bit word addressed, but in bursts of 4 64 bit words.
    // The address should always be a multiple of 4 (bottom 2 bits 0),
    // otherwise strange things will happen.
    // For example: address 0 refers to the first 4 64 bit words in memory.
    //              address 4 refers to the second 4 64 bit words in memory.
    DDR2Address address;

    // Data to write.
    // For read requests this is ignored.
    // Only those bytes with corresponding bit set in writeen will be written.
    DDR2Data datain;
} DDR2Request deriving(Bits, Eq);

// DDR2 Response.
// Data read from requested address.
// There will only be a response if writeen was 0 in the request.
typedef Bit#(256) DDR2Response;

typedef Client#(DDR2Request, DDR2Response) DDR2Client;

// Simulate a DDR2 with a register file.
// Bluesim is clever enough to support this (but don't try to synthesize it).
// This simulates the way I think the DDR2 should work functionally.
// This does NOT have the same timing behavior as DDR2.
module mkDDR2Simulator(DDR2_User);

    FIFO#(DDR2Response) responses <- mkFIFO();

    RegFile#(Bit#(29), DDR2Data) data <- mkRegFileFull();

    // Rotate 256 bit word by offset 64 bit words.
    function Bit#(256) rotate(Bit#(2) offset, Bit#(256) x);
        Vector#(4, Bit#(64)) words = unpack(x);
        Vector#(4, Bit#(64)) rotated = rotateBy(words, unpack((~offset) + 1));
        return pack(rotated);
    endfunction

    // Unrotate 256 bit word by offset 64 bit words.
    function Bit#(256) unrotate(Bit#(2) offset, Bit#(256) x);
        Vector#(4, Bit#(64)) words = unpack(x);
        Vector#(4, Bit#(64)) unrotated = rotateBy(words, unpack(offset));
        return pack(unrotated);
    endfunction


    method Bool init_done() = True;

    method Action put(Bit#(32) writeen, Bit#(31) addr, Bit#(256) datain);
        Bit#(29) burstaddr = addr[30:2];
        Bit#(2) offset = addr[1:0];

        Bit#(256) mask = 0;
        for (Integer i = 0; i < 32; i = i+1) begin
            if (writeen[i] == 'b1) begin
                mask[(i*8+7):i*8] = 8'hFF;
            end
        end

        Bit#(256) old_rotated = rotate(offset, data.sub(burstaddr));
        Bit#(256) new_masked = mask & datain;
        Bit#(256) old_masked = (~mask) & old_rotated;
        Bit#(256) new_rotated = new_masked | old_masked;
        Bit#(256) new_unrotated = unrotate(offset, new_rotated);
        data.upd(burstaddr, new_unrotated);

        if (writeen == 0) begin
            responses.enq(new_rotated);
        end
    endmethod

    method ActionValue#(DDR2Response) read();
        responses.deq();
        return responses.first();
    endmethod

endmodule

typedef 32 MAX_OUTSTANDING_READS;

instance Connectable#(DDR2Client, DDR2_User);
    module mkConnection#(DDR2Client cli, DDR2_User usr)(Empty);

        // Make sure we have enough buffer space to not drop responses!
        Counter#(TLog#(MAX_OUTSTANDING_READS)) reads <- mkCounter(0);
        FIFO#(DDR2Response) respbuf <- mkSizedFIFO(valueof(MAX_OUTSTANDING_READS));

        rule request (reads.value() != fromInteger(valueof(MAX_OUTSTANDING_READS)-1));
            let req <- cli.request.get();
            usr.put(req.writeen, req.address, req.datain);

            if (req.writeen == 0) begin
                reads.up();
            end
        endrule

        rule response (True);
            let x <- usr.read();
            respbuf.enq(x);
        endrule

        rule forward (True);
            let x <- toGet(respbuf).get();
            cli.response.put(x);
            reads.down();
        endrule
    endmodule
endinstance

// Brings a DDR2Client from one clock domain to another.
module mkDDR2ClientSync#(DDR2Client ddr2,
    Clock sclk, Reset srst, Clock dclk, Reset drst
    ) (DDR2Client);

    SyncFIFOIfc#(DDR2Request) reqs <- mkSyncFIFO(2, sclk, srst, dclk);
    SyncFIFOIfc#(DDR2Response) resps <- mkSyncFIFO(2, dclk, drst, sclk);

    mkConnection(toPut(reqs), toGet(ddr2.request));
    mkConnection(toGet(resps), toPut(ddr2.response));

    interface Get request = toGet(reqs);
    interface Put response = toPut(resps);
endmodule

