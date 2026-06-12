# CPU-memory-port capture for the upload-corruption hunt.
#
# xhunt4 verdict: the host uploads ZEROS for kernel offsets 0x6F0-0x70C,
# i.e. its reads of one 32B-aligned block of the embedded kernel array
# (CPU addr 0xDF020-0xDF03F) return zeros. This run logs the CPU AXI
# port; the cpumon process in metasat.vhd reports every access to
# 0xDF000-0xDF0FF in the transcript. The upload finishes by ~1.87 ms,
# so the run stops at 1.9 ms.
#
# Use via:  make -f setup_sim.mk TEST=parallel-nowrap WAVE_DO=wave-cpu.do run-wave
# Then grep the run log for CPUMON.

log /testbench/soc/sys/gpusys/vortex/wrap/vx_reset
log /testbench/soc/mem_aximo_sim
log /testbench/soc/cpu_mem_aximi
log /testbench/soc/cpu_mem_aximo
log -r /testbench/soc/sim_mem_gen/axi_mem_gen/mig_axiram/*

run 1900 us
quit -f
