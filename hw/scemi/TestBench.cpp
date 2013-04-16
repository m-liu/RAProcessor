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

#include <cassert>
#include <string>

#include "TestBench.h"

void response_cb(void* tb, const DDR2Response& response)
{
    ((TestBench*)tb)->handle_response(response);
}

TestBench::TestBench()
    : m_params("scemi.params"),
      m_scemi(SceMi::Init(SceMi::Version(SCEMI_VERSION_STRING), &m_params)),
      m_request("", "scemi_m_request_inport", m_scemi),
      m_response("", "scemi_m_response_outport", m_scemi),
      m_holdback("", "scemi_m_holdback_inport", m_scemi),
      m_shutdown("", "scemi_m_shutdown", m_scemi)
{
    m_response.setCallBack(response_cb, this);
    m_sthread = new SceMiServiceThread(m_scemi);
}

TestBench::~TestBench()
{
    m_shutdown.blocking_send_finish();
    m_sthread->stop();
    m_sthread->join();
    SceMi::Shutdown(m_scemi);
    delete m_sthread;
}

void TestBench::request(unsigned int writeen, unsigned int addr,
        unsigned long long di0, unsigned long long di1,
        unsigned long long di2, unsigned long long di3)
{
    DDR2Request request;
    request.m_writeen = writeen;
    request.m_address = addr;

    request.m_datain.setWord(0, di0 & 0xFFFFFFFF);
    request.m_datain.setWord(1, (di0 >> 32) & 0xFFFFFFFF);
    request.m_datain.setWord(2, di1 & 0xFFFFFFFF);
    request.m_datain.setWord(3, (di1 >> 32) & 0xFFFFFFFF);
    request.m_datain.setWord(4, di2 & 0xFFFFFFFF);
    request.m_datain.setWord(5, (di2 >> 32) & 0xFFFFFFFF);
    request.m_datain.setWord(6, di3 & 0xFFFFFFFF);
    request.m_datain.setWord(7, (di3 >> 32) & 0xFFFFFFFF);

    m_request.sendMessage(request);
    std::cerr << "sent request: " << request << std::endl;
}

void TestBench::handle_response(const DDR2Response& response)
{
    std::cout << "got response: " << response << std::endl;
}

void TestBench::run()
{
    // We accept these commands:
    // request <writeen> <addr> <datain0> <datain1> <datain2> <datain3>
    //  - Send a raw DDR2 request with given writeen, addr, datain.
    //    datain0 is the least significant 64 bit word of datain,
    //    datain3 is the most significant 64 bit word of datain.
    // read <addr>
    //  - Read data at given address.
    // write <addr> <datain0> <datain1> <datain2> <datain3>
    //  - Write given data to given address.
    // hold  - start holding requests
    // unhold - stop holding requests
    // quit
    //  - quit the test bench.

    std::string cmd;
    bool done = false;

    unsigned int writeen;
    unsigned int addr;
    unsigned long long di0;
    unsigned long long di1;
    unsigned long long di2;
    unsigned long long di3;
    const unsigned long long dontcare = 0xAAAAAAAAAAAAAAAALL;

    while (std::cin && !done) {
        std::cin >> cmd;

        if (cmd == "quit") {
            done = true;
        } else if (cmd == "hold") {
            m_holdback.sendMessage(BitT<1>(1));
        } else if (cmd == "unhold") {
            m_holdback.sendMessage(BitT<1>(0));
        } else if (cmd == "request") {
            std::cin >> writeen;
            std::cin >> addr;
            std::cin >> di0;
            std::cin >> di1;
            std::cin >> di2;
            std::cin >> di3;

            request(writeen, addr, di0, di1, di2, di3);
        } else if (cmd == "read") {
            writeen = 0;
            std::cin >> addr;
            di0 = dontcare;
            di1 = dontcare;
            di2 = dontcare;
            di3 = dontcare;

            request(writeen, addr, di0, di1, di2, di3);
        } else if (cmd == "write") {
            writeen = 0xFFFFFFFF;
            std::cin >> addr;
            std::cin >> di0;
            std::cin >> di1;
            std::cin >> di2;
            std::cin >> di3;

            request(writeen, addr, di0, di1, di2, di3);
        } else if (cmd == "help") {
            std::cout << "request <writeen> <addr> <datain0> <datain1> <datain2> <datain3>" << std::endl;
            std::cout << "\t- Send a raw DDR2 request with given writeen, addr, datain" << std::endl;
            std::cout << "\t  datain0 is the least significant 64 bit word of datain" << std::endl;
            std::cout << "\t  datain3 is the most significant 64 bit word of datain" << std::endl;
            std::cout << "read <addr>" << std::endl;
            std::cout << "\t- Read data at given address" << std::endl;
            std::cout << "write <addr> <datain0> <datain1> <datain2> <datain3>" << std::endl;
            std::cout << "\t- Write given data to given address" << std::endl;
            std::cout << "quit" << std::endl;
            std::cout << "\t- quit the test bench." << std::endl;
        } else {
            std::cout << cmd << ": invalid command" << std::endl;
        }
    }
}

int main(int argc, char* argv[])
{
    TestBench tb;
    tb.run();

    // Wait just a little to let outstanding responses come in.
    std::cout << "waiting a little for outstanding responses..." << std::endl;
    sleep(1);
}

