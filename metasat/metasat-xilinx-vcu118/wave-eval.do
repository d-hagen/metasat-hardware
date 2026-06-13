# Waveform capture for the evaluation / evaluation-light hang
# (vx_spawn_threads library path; hangs after "Waiting for execution to
# complete" with vx_busy stuck high).
#
# Same core scopes as wave-axi.do plus the muldiv unit internals (this
# kernel is the first test to execute divu/remu and an indirect jalr
# callback through the spawn library). Run length is 6 ms: the host
# reaches "Start execution" at ~1.85 ms (upload) and the GPU compute for
# SIZE=16 is short, so the hang state is established well before 6 ms.
#
# Use via:  make -f setup_sim.mk TEST=evaluation-light WAVE_DO=wave-eval.do run-wave
#
# After the run, inspect on the WLF (no rerun needed):
#   warp_pcs / stalled_warps / active_warps at the hang  -> map PCs to
#   /tmp/eval-kernel.dump:
#     ~0x60000384-0x60000398 (divu/remu) + muldiv valid stuck  -> H1 muldiv
#     a warp PC outside 0x60000000-0x60007xxx, or int_execute_if = X
#                                                              -> H2 mscratch/stack race
#     all warps idle but vx_busy=1                             -> AFU busy/done logic
#   The xhunt*.do scripts apply unchanged if X reappears.

set CORE {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core}

log /testbench/soc/sys/gpusys/vortex/wrap/vx_reset
log /testbench/soc/sys/gpusys/vortex/wrap/vx_busy

log -r ${CORE}/schedule/*
log -r ${CORE}/fetch/*
log -r ${CORE}/decode/*
log -r ${CORE}/issue/*
log -r ${CORE}/execute/alu_unit/*
log -r ${CORE}/execute/lsu_unit/*
log -r ${CORE}/execute/sfu_unit/*
log -r ${CORE}/commit/*

# GPU memory AXI port + unique-ID glue (same as wave-axi.do)
log /testbench/soc/gpu_aximo_sim
log /testbench/soc/gpu_mem_aximi
log /testbench/soc/gpu_mem_aximo
log /testbench/soc/gpu_wr_id
log /testbench/soc/gpu_wr_awdone
log /testbench/soc/gpu_wr_wdone
log -r /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram/*

# AFU control/busy path: distinguishes "GPU still computing" from
# "compute done but busy/done handshake stuck" (vx_busy never falls).
log -r /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/*

run 6000 us
quit -f
