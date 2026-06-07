# Targeted waveform logging for GPU hang diagnosis.
# Captures only the critical signals — keeps WLF file small despite 500M cycle run.

log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_reset
log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_busy
log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_running
log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_busy_wait

log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/active_warps}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/stalled_warps}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/thread_masks}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/warp_pcs}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/wspawn}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/is_single_warp}

run 100000000 ns
quit -f
