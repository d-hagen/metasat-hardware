# Targeted waveform logging for GPU hang diagnosis.
# Captures the AFU busy state, the schedule unit, and the full core pipeline
# (fetch/decode/issue/execute/commit) to localize wstall instructions that
# never resolve. Caches/LSU memories excluded to bound WLF size.

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

run 20000000 ns
quit -f
