# wave-s15.do -- capture the GPU memory data path for the size-15 remainder hunt.
#
# No vx_busy poll, no absolute-time skip -- both are fragile for a fast-completing
# test (vx_busy is high only ~tens of us during the microsecond compute). Instead:
# enable logging from t=0 and run the WHOLE sim. We accept a larger WLF in
# exchange for never missing the capture window -- bloat beats a rerun.
#
# Note: regions (generate/instance scopes like sim_mem_gen) must be logged with a
# trailing /* ; named signals (gpu_aximo_sim, ...) are logged directly.
#
# Use:  make -f setup_sim.mk TEST=evaluation-s15 WAVE_DO=wave-s15.do run-wave

set CORE {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core}

log /testbench/soc/sys/gpusys/vortex/wrap/vx_reset
log /testbench/soc/sys/gpusys/vortex/wrap/vx_busy

# --- the memory data path the dest value travels through ---
#   sim_mem_gen/* : BOTH sim memories -- gpu_axiram (GPU) + mig_axiram (CPU),
#                   incl. rbin (writes INTO backing store: addr/wr/din),
#                   rbout (reads OUT: addr/dout), aximem wq/wdq match queues.
#   *_mem_aximo/i + *_sim : the GPU and CPU AXI ports (incl. read-back path).
log -r /testbench/soc/sim_mem_gen/*
log -r /testbench/soc/gpu_aximo_sim
log -r /testbench/soc/gpu_mem_aximi
log -r /testbench/soc/gpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximi
log -r /testbench/soc/mem_aximo_sim

# --- the GPU core pipeline, so we never have to rerun for it either ---
log -r ${CORE}/schedule/*
log -r ${CORE}/fetch/*
log -r ${CORE}/decode/*
log -r ${CORE}/issue/*
log -r ${CORE}/execute/lsu_unit/*
log -r ${CORE}/commit/*

set rbsigs {}
catch {set rbsigs [find signals /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram/*]}
echo "wave-s15: gpu_axiram resolves to [llength $rbsigs] signals (MUST be >0)"

# Run the whole sim (upload ~10ms, compute ~10.715ms, test done ~11.5ms), in 1ms
# chunks so progress is visible (logged whole-run is slower; this isn't a hang).
echo "wave-s15: logging from t=0, running the full sim..."
for {set ms 1} {$ms <= 15} {incr ms} {
    run 1 ms
    echo "wave-s15:   t=${ms} ms"
}
quit -f
