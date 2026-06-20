# wave-s15.do -- one-shot capture for the size-15 partial-warp remainder hunt.
#
# The size-15 eval upload takes ~10 ms of sim time; we skip it by polling
# vx_busy, then log the FULL core pipeline + LSU + GPU memory port for the
# (tiny) compute window. Combined with the GPUWR print probe in metasat.vhd,
# one run yields: transcript (pass/fail + GPU store data) AND a WLF for
# post-hoc xhunt analysis of whether the remainder warp (warp 0, tmask 0b0111)
# executes, loads src[12..14], and issues the dest[12..14] stores.
#
# Use:  make -f setup_sim.mk TEST=evaluation-s15 WAVE_DO=wave-s15.do run-wave

set CORE {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core}
set VXBUSY /testbench/soc/sys/gpusys/vortex/wrap/vx_busy

log /testbench/soc/sys/gpusys/vortex/wrap/vx_reset
log $VXBUSY

echo "wave-s15: fast-forwarding through the ~10ms upload until vx_busy asserts..."
set tcap 0
while {1} {
    set v [examine $VXBUSY]
    if {[regexp {1$} $v]} { break }
    if {$tcap >= 60000} { echo "wave-s15: vx_busy never asserted by 60ms"; break }
    run 500 us
    set tcap [expr {$tcap + 500}]
    # progress heartbeat: if this number keeps climbing the sim is advancing
    # (just slow); if it freezes at one value the sim is genuinely hung.
    echo "wave-s15:   fast-forward t=${tcap}us  vx_busy=$v"
}
echo "wave-s15: vx_busy asserted after ${tcap} us -- logging compute window"

log -r ${CORE}/schedule/*
log -r ${CORE}/fetch/*
log -r ${CORE}/decode/*
log -r ${CORE}/issue/*
log -r ${CORE}/execute/alu_unit/*
log -r ${CORE}/execute/lsu_unit/*
log -r ${CORE}/execute/sfu_unit/*
log -r ${CORE}/commit/*

# Capture the ENTIRE memory data path the dest value can travel through -- but
# NOT the giant GPU/CPU compute internals (those would balloon the WLF and make
# the logged window crawl for zero benefit; we already proved the GPU emits the
# right data at its port). -r is required so -view can examine record sub-fields.
#
#   sim_mem_gen : BOTH sim memories -- gpu_axiram (GPU) + mig_axiram (CPU) --
#                 incl. rbin (writes INTO the backing store: addr/wr/din),
#                 rbout (reads OUT: addr/dout), and aximem's wq/wdq match queues.
#   *_mem_aximo/i + *_sim : the GPU and CPU AXI ports (incl. the read-back path).
#
# Read-out: rbin.wr=0x7000 + din bytes 12-14 = 18/1a/1c at the dest line means
# the remainder store landed in memory; rbout.dout byte 12 on the read-back tells
# whether the read sees it (0x18) or not (UU/00) -> splits write- vs read-side.
log -r /testbench/soc/sim_mem_gen
log -r /testbench/soc/gpu_aximo_sim
log -r /testbench/soc/gpu_mem_aximi
log -r /testbench/soc/gpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximi
log -r /testbench/soc/mem_aximo_sim

set rbsigs {}
catch {set rbsigs [find signals /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram/*]}
echo "wave-s15: gpu_axiram resolves to [llength $rbsigs] signals (must be >0; if 0, tell me -- the path is wrong and rbin/rbout won't be captured)"

# Run until the GPU finishes (vx_busy deasserts), then a short margin for the
# CPU readback + "Test passed/failed" print, then quit. A fixed "run 3000 us"
# kept simulating ~3 ms of *idle* SoC after the test had already finished,
# which (with full logging) looks frozen for minutes. This stops right after.
set tdone 0
while {[regexp {1$} [examine $VXBUSY]]} {
    if {$tdone >= 5000} { echo "wave-s15: vx_busy still high after 5ms compute -- stopping"; break }
    run 100 us
    set tdone [expr {$tdone + 100}]
    echo "wave-s15:   compute (logging) t=+${tdone}us  vx_busy=high"
}
echo "wave-s15: vx_busy deasserted after ${tdone} us of compute; +200us margin then quit"
run 200 us
quit -f
