# wave-s15.do -- capture the GPU memory data path for the size-15 remainder hunt.
#
# IMPORTANT: we gate logging on ABSOLUTE TIME, not by polling vx_busy. vx_busy is
# high only for ~tens of us during the (microsecond) compute, so a 500us poll
# sampled past it every time -> the old loop never broke and the log statements
# below never ran (every prior WLF was effectively empty). The GPUWR probe shows
# the kernel upload writes start after 9 ms and the dest stores are at ~10.715 ms,
# so: run unlogged to 9 ms, enable logging, then run through 12 ms.
#
# Use:  make -f setup_sim.mk TEST=evaluation-s15 WAVE_DO=wave-s15.do run-wave

log /testbench/soc/sys/gpusys/vortex/wrap/vx_reset
log /testbench/soc/sys/gpusys/vortex/wrap/vx_busy

echo "wave-s15: skipping the ~9 ms upload (unlogged) by absolute time..."
run 9 ms
echo "wave-s15: at 9 ms -- enabling memory-data-path logging"

# The ENTIRE path the dest value can travel through (small -- a few hundred nets;
# NOT the giant GPU/CPU compute internals). -r so -view can read record fields.
#   sim_mem_gen : BOTH sim memories -- gpu_axiram (GPU) + mig_axiram (CPU) --
#                 rbin (writes INTO backing store: addr/wr/din), rbout (reads
#                 OUT: addr/dout), and aximem's wq/wdq match queues.
#   *_mem_aximo/i + *_sim : the GPU and CPU AXI ports (incl. the read-back path).
log -r /testbench/soc/sim_mem_gen
log -r /testbench/soc/gpu_aximo_sim
log -r /testbench/soc/gpu_mem_aximi
log -r /testbench/soc/gpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximi
log -r /testbench/soc/mem_aximo_sim

set rbsigs {}
catch {set rbsigs [find signals /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram/*]}
echo "wave-s15: gpu_axiram resolves to [llength $rbsigs] signals (MUST be >0; if 0 the path is wrong)"

# Run through compute (~10.715 ms) + read-back (~10.8 ms), with a heartbeat so
# the logged window visibly advances instead of looking frozen.
for {set ms 10} {$ms <= 12} {incr ms} {
    run 1 ms
    echo "wave-s15:   logged run -> sim now ~${ms} ms"
}
quit -f
