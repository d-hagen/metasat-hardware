# wave-8core.do -- chase the 8-core "completes but wrong data" bug.
#
# Symptom (FPGA, 8 GPU cores; 2 cores is clean, all sizes pass):
#   * evaluation -> all-zero output, every size incl. powers of two (fails at pos 0)
#   * VecAdd     -> flaky: passes for many sizes, fails for some (342, 198, 1024),
#                  and the outcome depends on EXECUTION HISTORY (run 400 "fixes" 342,
#                  run 1024 "breaks" it again)
#   * VecAdd 2048 -> all -1 == dest init value -> NO store reached the target
#
# Leading hypotheses this capture must adjudicate:
#   T1  AXI memory-tag aliasing/truncation. VX_MEM_TAG_WIDTH grows with cores/
#       sockets/clusters (built from UUID_WIDTH + per-level arb bits). The SoC AXI
#       id is fixed at AXI_ID_WIDTH=32 and Vortex_axi.sv's guard assert (line 87,
#       AXI_TID_WIDTH >= VX_MEM_TAG_WIDTH) is COMMENTED OUT, with truncation at
#       lines 118-119. If the tag exceeds 32 (or the in-flight tag space aliases
#       under 8-core occupancy), memory RESPONSES mis-route -> wrong data, no stall.
#       Occupancy-dependent aliasing explains the size/history-dependent VecAdd.
#   T2  core_id / socket enumeration across 2 sockets (4 cores/socket). Wrong
#       vx_core_id/vx_num_cores -> wrong per-core all_tasks_offset -> cores write
#       overlapping/wrong address ranges. (Deterministic per size.)
#   T3  stale-readback amplifier: allocator reuses the same device addresses each
#       run and eval clears dest to 0 / VecAdd to -1; dropped stores then read back
#       as cleared (eval=0) or prior-run residue (VecAdd history-dependence).
#
# Strategy: reruns are EXTREMELY expensive -> over-capture the memory-routing locus
# and every core's store path, then run the whole sim. We bound the per-core
# capture to schedule/issue/lsu/commit (the store story) rather than full ALU/fetch
# internals, to keep the WLF within /dades and the sim from crawling. If T1/T2 are
# not settled from this, uncomment the FULL-VORTEX fallback at the bottom.
#
# Use:  make -f setup_sim.mk TEST=<eval-8core srec> WAVE_DO=wave-8core.do run-wave

set VX   {/testbench/soc/sys/gpusys/vortex/wrap}
set AXI  ${VX}/vortex_axi
set TOP  ${AXI}/vortex

log ${VX}/vx_reset
log ${VX}/vx_busy

# ---- T1: THE tag-truncation locus -- FULL. m_axi_awid/arid/rid/bid, mem_req_tag,
#      mem_rsp_tag, and the *_unqual truncation wires. Prime suspect; small scope.
log -r ${AXI}/*

# ---- SoC-side memory data path (what actually lands + host readback), as wave-s15.
#      gpu_axiram = device memory, mig_axiram = host/CPU memory; rbin=writes in,
#      rbout=reads out; aximem wq/wdq = the W<->AW match queues (by id).
log -r /testbench/soc/sim_mem_gen/*
log -r /testbench/soc/gpu_aximo_sim
log -r /testbench/soc/gpu_mem_aximi
log -r /testbench/soc/gpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximo
log -r /testbench/soc/cpu_mem_aximi
log -r /testbench/soc/mem_aximo_sim

# ---- per-core STORE path for ALL 8 cores (2 sockets x 4 cores). schedule = warp/
#      PC/tmask (core identity + which task), issue = dispatched store addr/data,
#      execute/lsu_unit = dcache req addr/data/tag/byteen + response, commit.
#      catch-guarded so a missing socket/core index can't abort the run.
set ncov 0
for {set s 0} {$s < 2} {incr s} {
  for {set c 0} {$c < 4} {incr c} {
    set CORE "${TOP}/clusters\[0\]/cluster/sockets\[$s\]/socket/cores\[$c\]/core"
    set hit 0
    catch { log -r ${CORE}/schedule/*        ; set hit 1 }
    catch { log -r ${CORE}/issue/* }
    catch { log -r ${CORE}/execute/lsu_unit/* }
    catch { log -r ${CORE}/commit/* }
    if {$hit} { incr ncov ; echo "wave-8core: logged store path for core s${s}c${c}" }
  }
}
echo "wave-8core: per-core store path logged for $ncov / 8 cores (MUST be 8)"

# ---- T2 / socket: caches + global barrier + mem interconnect. Instance names vary
#      by config, so discover and log under catch (never abort the run).
foreach sub {l2cache l3cache mem_arb mem_xbar xbar gbar gbar_unit barrier mem_unit} {
  set hits {}
  catch { set hits [find instances -recursive ${TOP}/* -bydu $sub] }
  if {[llength $hits] == 0} { catch { set hits [find instances -recursive ${TOP}/*${sub}*] } }
  if {[llength $hits] > 0} {
    foreach h $hits { catch { log -r ${h}/* } }
    echo "wave-8core: logged [llength $hits] instance(s) matching '$sub'"
  }
}

# ---- sanity: the AXI adapter id wires must resolve (else paths are wrong).
set axisig {}
catch { set axisig [find signals -recursive ${AXI}/* awid] }
echo "wave-8core: vortex_axi 'awid' resolves to [llength $axisig] net(s) (MUST be >0)"

# ---- run the WHOLE sim in 1ms chunks so progress is visible (8-core: expect slow;
#      slow != hung). Upload ~10ms dominates; compute window follows.
echo "wave-8core: logging from t=0, running full sim (8 cores)..."
for {set ms 1} {$ms <= 25} {incr ms} {
  run 1 ms
  echo "wave-8core:   t=${ms} ms"
}
quit -f

# ---- FULL-VORTEX FALLBACK (uncomment only if T1/T2 unresolved; huge WLF + slow):
# log -r ${TOP}/*
