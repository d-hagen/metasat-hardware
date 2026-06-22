// Diagnostic: print the COMPILED VX_MEM_TAG_WIDTH from the work lib's VX_gpu_pkg.
//   23 = UUID-widen fix (fix 1) is in the build;  9 = stale (fix not compiled).
//
// Safe to run while a sim is in progress: it compiles into a throwaway lib and
// only READS the already-compiled VX_gpu_pkg from work (never writes to work).
// From metasat/metasat-xilinx-vcu118/ (csh shell uses |&, not 2>&1|):
//   vlib /tmp/probelib
//   vlog -work /tmp/probelib -sv +incdir+../../extra/vortex/hw/syn/soc/src -L work tagprobe.sv
//   vsim -c -L work /tmp/probelib.tagprobe -do "run -all; quit -f" |& grep ">>>"
`include "VX_define.vh"
module tagprobe;
  import VX_gpu_pkg::*;
  initial begin
    $display(">>> VX_MEM_TAG_WIDTH = %0d  (23 = fix1 IN, 9 = NOT)", `VX_MEM_TAG_WIDTH);
    $finish;
  end
endmodule
