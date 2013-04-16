import SceMi::*;
import SceMiLayer::*;

// Setup for SCE-MI over PCIE to a Virtex5
import Xilinx::*;
import XilinxPCIE::*;
import Clocks::*;
import DefaultValue::*;

import XilinxDDR2::*;
import Connectable::*;

import DDR2::*;

// We need to get access to the uncontrolled clock and reset to hook up the
// ddr2. This is a hack to get at that info.
interface DDR2SceMiLayerIfc;
    interface DDR2Client ddr2;
    interface Clock uclock;
    interface Reset ureset;
endinterface

module [SceMiModule] mkDDR2SceMiLayerWrapper(DDR2SceMiLayerIfc);

    // It appears the clock port must be instantiated in the top level
    // SceMiModule, otherwise the ucf file is messed up. So put it here (this
    // makes me sad).
    SceMiClockConfiguration conf = defaultValue;
    SceMiClockPortIfc clk_port <- mkSceMiClockPort(conf);

    DDR2Client m <- mkSceMiLayer(clk_port);
    Clock uclk <- sceMiGetUClock;
    Reset urst <- sceMiGetUReset;

    interface ddr2 = m;
    interface uclock = uclk;
    interface ureset = urst;
endmodule

SceMiLinkType lt = PCIE_VIRTEX5;

(* synthesize, no_default_clock, no_default_reset *)
module mkBridge #(Clock pci_sys_clk_p, Clock pci_sys_clk_n,
		  Clock refclk_100, Clock clk200, Reset pci_sys_reset_n)
                 (ML50x_FPGA_DDR2);

   ClockGeneratorParams clk_params = defaultValue();
   clk_params.feedback_mul = 10; // 1000 MHz VCO frequency
   clk_params.clk0_div     = 10; // 100 MHz
   clk_params.clk1_div     = 8;  // 125 MHz
   clk_params.clk1_buffer  = False;
   ClockGenerator clk_gen <- mkClockGenerator(clk_params, clocked_by refclk_100, reset_by pci_sys_reset_n);

   Reset scemi_reset <- mkAsyncReset( 3, pci_sys_reset_n, clk_gen.clkout0 );

   Clock g1_clk = clk_gen.clkout1;
   Reset g1_rstn <- mkAsyncReset(0, scemi_reset, g1_clk);

   DDR2_Configure ddr2_cfg;
   ddr2_cfg.clk_period_in_ps    = 8000;
   ddr2_cfg.num_reads_in_flight = 2;
   ddr2_cfg.fast_train_sim_only = False; // set to true for faster simulations with ddr2

   DDR2_Controller ddr2_ctrl <- mkDDR2Controller( ddr2_cfg, clk200, clocked_by g1_clk, reset_by g1_rstn );

   SceMiV5PCIEArgs pcie_args;
   pcie_args.pci_sys_clk_p = pci_sys_clk_p;
   pcie_args.pci_sys_clk_n = pci_sys_clk_n;
   pcie_args.pci_sys_reset = pci_sys_reset_n;
   pcie_args.ref_clk       = clk_gen.clkout0;
   pcie_args.link_type     = lt;

   (* doc = "synthesis attribute buffer_type of scemi_pcie_ep_trn_clk is \"none\"" *)
   (* doc = "synthesis attribute keep of scemi_pcie_ep_trn2_clk is \"true\";" *)
   SceMiV5PCIEIfc#(DDR2SceMiLayerIfc, 1) scemi <- buildSceMi(mkDDR2SceMiLayerWrapper, pcie_args);

   ReadOnly#(Bool) _isLinkUp         <- mkNullCrossing(noClock, scemi.isLinkUp);
   ReadOnly#(Bool) _isOutOfReset     <- mkNullCrossing(noClock, scemi.isOutOfReset);
   ReadOnly#(Bool) _isClockAdvancing <- mkNullCrossing(noClock, scemi.isClockAdvancing);

   DDR2Client client_in_domain <- mkDDR2ClientSync(scemi.orig_ifc.ddr2,
       scemi.orig_ifc.uclock, scemi.orig_ifc.ureset, ddr2_ctrl.user.clock,
       ddr2_ctrl.user.reset_n);

   mkConnection(client_in_domain, ddr2_ctrl.user, clocked_by ddr2_ctrl.user.clock, reset_by ddr2_ctrl.user.reset_n);

   interface pcie = scemi.pcie;
   interface ddr2 = ddr2_ctrl.ddr2;

   method leds = zeroExtend({pack(_isClockAdvancing)
			    ,pack(_isOutOfReset)
			    ,pack(_isLinkUp)
			    });
endmodule: mkBridge

