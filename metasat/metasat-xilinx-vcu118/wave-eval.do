# Waveform capture for the evaluation / evaluation-light hang
# (vx_spawn_threads library path; hangs after "Waiting for execution to
# complete").
#
# The kernel is ~30 KB and the host uploads it word-by-word over MMIO,
# which takes >10 ms of SIM time before compute even starts. So we:
#   1. log only vx_busy/vx_reset and fast-forward through the upload in
#      500 us chunks WITHOUT heavy pipeline logging (small WLF),
#   2. as soon as vx_busy asserts (compute started), switch on full
#      pipeline + AXI + AFU logging,
#   3. run UNBOUNDED -- stop manually with Ctrl-C once the stall is
#      reached (transcript time has climbed well past "Waiting for
#      execution to complete" with no further host output). The WLF is
#      flushed on Ctrl-C.
#
# After Ctrl-C, at the VSIM> prompt, analyse in the SAME session:
#   do metasat/metasat-xilinx-vcu118/xhunt5.do
# (xhunt5 defaults THANG=now, so it reads the stall-time values directly).
# Or reopen later: vsim -c -view <wlf> -do "do .../xhunt5.do"
#
# Use via:  make -f setup_sim.mk TEST=evaluation-light WAVE_DO=wave-eval.do run-wave

set CORE {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core}
set VXBUSY /testbench/soc/sys/gpusys/vortex/wrap/vx_busy

# --- lightweight markers across the whole run (incl. the upload phase) ---
log /testbench/soc/sys/gpusys/vortex/wrap/vx_reset
log $VXBUSY

# --- fast-forward through the kernel upload until vx_busy asserts ---
echo "wave-eval: fast-forwarding through upload until vx_busy asserts (vx_busy-only logging)..."
set tcap 0
while {1} {
    set v [examine $VXBUSY]
    if {[regexp {1$} $v]} { break }
    if {$tcap >= 60000} {
        echo "wave-eval: vx_busy still 0 at 60 ms -- enabling full logging anyway (GPU may never have started)"
        break
    }
    run 500 us
    set tcap [expr {$tcap + 500}]
}
echo "wave-eval: vx_busy=$v after ${tcap} us -- enabling full pipeline logging"

# --- full pipeline + AXI + AFU logging from the moment compute starts ---
log -r ${CORE}/schedule/*
log -r ${CORE}/fetch/*
log -r ${CORE}/decode/*
log -r ${CORE}/issue/*
log -r ${CORE}/execute/alu_unit/*
log -r ${CORE}/execute/lsu_unit/*
log -r ${CORE}/execute/sfu_unit/*
log -r ${CORE}/commit/*

log /testbench/soc/gpu_aximo_sim
log /testbench/soc/gpu_mem_aximi
log /testbench/soc/gpu_mem_aximo
log /testbench/soc/gpu_wr_id
log /testbench/soc/gpu_wr_awdone
log /testbench/soc/gpu_wr_wdone
log -r /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram/*

log -r /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/*

echo "wave-eval: capturing -- run is UNBOUNDED. Ctrl-C at the stall, then: do metasat/metasat-xilinx-vcu118/xhunt5.do"
run -all
quit -f
