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

#ifndef TESTBENCH_H
#define TESTBENCH_H

#include "SceMiHeaders.h"

// Not sure why bluespec doesn't generate this alias automatically...
typedef BitT<256> DDR2Response;

class TestBench
{
public:
    TestBench();
    ~TestBench();

    void run();
    void handle_response(const DDR2Response& response);

private:

    void request(unsigned int writeen, unsigned int addr,
        unsigned long long di0, unsigned long long di1,
        unsigned long long di2, unsigned long long di3);

    // Sce-Mi stuff
    SceMiParameters m_params;
    SceMi* m_scemi;
    SceMiServiceThread* m_sthread;

    // Transactors
    InportProxyT<DDR2Request> m_request;
    OutportProxyT<DDR2Response> m_response;
    InportProxyT<BitT<1> > m_holdback;

    // Shutdown Transactor
    ShutdownXactor m_shutdown;
};

#endif//TESTBENCH_H

