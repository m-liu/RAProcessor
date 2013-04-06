
= Sample Project Demonstrating DDR2 with SceMi =

This project demonstrates one way to use DDR2 on the XUPV5 FPGA with the 
Bluespec SceMi infrastructure. The application is a shell with
commands to read and write data at specific memory addresses, or to perform a
raw DDR2 request. There is code to run the project both in simulation and on
the FPGA. In simulation the DDR2 is simulated with a RegFile and read latency
is not meaningful.

== Local Files ==
ddr2/DDR2.bsv
    Defines DDR2Request and DDR2Response types, a client interface for DDR2,
    the implementation of a simulated DDR2 using a RegFile, a way to connect a
    DDR2 client to the DDR2_User interface provided by Bluespec, and a module
    for crossing a DDR2 client from one clock domain to another.

scemi/
    Code for sample application common to both simulation and FPGA. The
    application accepts read and write commands from stdin of the host
    processor, sends those commands over the SceMi link, forwards them to the
    DDR2 controller, and sends responses from the DDR2 controller back over
    the SceMi link to the host processor which prints them to stdout.

sim/
    Project files for running in simulation. This uses the mkDDR2Simulator.
    
fpga/
    Project files for running on the FPGA.

inputs/
    Sample input to shell program.

== Relevant Files from Bluespec Installation ==
$BLUESPECDIR/BSVSource/Xilinx/XilinxDDR2.bsv
    Defines DDR2_User interface, Bluespec wrapper over mig generated DDR2
    controller.

$BLUESPECDIR/board_support/bluenoc/xilinx/XUPV5/verilog/ddr2_v3_5/
    Verilog code for mig generated DDR2 controller.

== References ==
http://www.xilinx.com/support/documentation/ip_documentation/ug086.pdf

Documentation for mig generated memory controller. Pages 361-394 are relevant
to us.

== Notes ==
The ucf constraints Bluespec provides for DDR2 on XUPV5 is buggy and will not
work. The fixed version is provided in the file
doc/DDR2_synthesis_constraints. For this project to work, you must change the
Bluespec installation to use this file instead of its buggy version. (This has
already been done for the installation on the 6.375 course locker). For
example, to fix the installation run

  $ cp doc/DDR2_synthesis_constraints $BLUESPECDIR/board_support/bluenoc/xilinx/XUPV5

== Bugs ==
On occasion when running the test bench a couple bits are flipped in the DDR2
responses. I'm not sure if this is a problem with the DDR2, the PCIe link, or
something else. If you encounter this behavior and have any ideas what's going
on, please email me at ruhler@mit.edu.

