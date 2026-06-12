# wave.do + GPU AXI port logging, trimmed run.
#
# Adds the GPU memory AXI port (post-glue requests, aximem responses), the
# unique-ID glue state, and the aximem read-queue debug to the original core
# scopes. Run length cut to 4.6 ms: the parallel-nowrap hang locks at
# ~4.509 ms, so 20 ms wastes 4x the sim time.
#
# Purpose: decide whether the zeroed icache line at 0x60000700 comes from
# memory (upload hole -> AXI R returns zeros) or from the icache itself
# (R returns the correct line, fetch still gets zeros).
#
# Use via:  make -f setup_sim.mk TEST=parallel-nowrap WAVE_DO=wave-axi.do run-wave

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

# GPU memory AXI port: requests after the unique-ID glue, responses from aximem
log /testbench/soc/gpu_aximo_sim
log /testbench/soc/gpu_mem_aximi
log /testbench/soc/gpu_wr_id
log /testbench/soc/gpu_wr_awdone
log /testbench/soc/gpu_wr_wdone
# raw Vortex-side request (pre-glue) for ID comparison
log /testbench/soc/gpu_mem_aximo
# aximem internals (read queue debug)
log -r /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram/*

run 4600 us
quit -f
