# Waveform capture for the evaluation / evaluation-light hang
# (vx_spawn_threads library path; hangs after "Waiting for execution to
# complete" with vx_busy stuck high).
#
# IMPORTANT timing: the kernel is ~30 KB and the host uploads it word-by-
# word over MMIO at ~3.3 B/us, so the upload alone runs to ~10.3 ms of
# SIM time before compute even starts (measured from CPUMON: ~228 B in
# 68 us around the 0xDF000 page). We therefore:
#   1. log only vx_busy/vx_reset and fast-forward through the upload
#      WITHOUT heavy pipeline logging (keeps the WLF small),
#   2. switch on full pipeline + AXI + AFU logging at 9 ms (just before
#      upload completes), and capture the compute + stall window.
#
# Scopes added vs wave-axi.do: muldiv unit internals (first test to run
# divu/remu + an indirect jalr callback through the spawn library) and
# the afu_ctrl busy/done path.
#
# Use via:  make -f setup_sim.mk TEST=evaluation-light WAVE_DO=wave-eval.do run-wave
#
# If you prefer to stop manually: replace "run 7000 us" below with
# "run -all" and Ctrl-C once "Waiting for execution to complete" has
# printed and the transcript time has climbed a few ms past it (the WLF
# is flushed on Ctrl-C). Then run xhunt5.do on the WLF.

set CORE {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core}

# --- lightweight markers across the whole run (incl. the upload phase) ---
log /testbench/soc/sys/gpusys/vortex/wrap/vx_reset
log /testbench/soc/sys/gpusys/vortex/wrap/vx_busy

# --- fast-forward through the ~10 ms kernel upload, no heavy logging ---
echo "wave-eval: fast-forwarding through kernel upload (vx_busy-only)..."
run 9000 us

# --- upload nearly done: enable full pipeline + AXI + AFU logging ---
echo "wave-eval: enabling full pipeline logging, capturing compute + stall"
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

# 9 ms -> 16 ms: covers upload tail (~10.3 ms), compute, and the
# established stall. THANG in xhunt5.do defaults to 15 ms (deep in stall).
run 7000 us
quit -f
