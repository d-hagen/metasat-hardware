# Targeted waveform logging for GPU hang diagnosis.
# Captures only the critical signals — keeps WLF file small despite long runs.

log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_reset
log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_busy
log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_running
log /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/vx_busy_wait

# Scheduler state (present + next-state to distinguish "just changed" from "stable")
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/active_warps}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/active_warps_n}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/stalled_warps}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/stalled_warps_n}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/thread_masks}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/thread_masks_n}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/warp_pcs}

# Pending wspawn register + gate
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/wspawn}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/wspawn_wid}
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/schedule/is_single_warp}

# Decode->schedule (who's about to stall and why)


run 20000000 ns
quit -f
