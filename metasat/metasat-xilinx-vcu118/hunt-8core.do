# hunt-8core.do -- 8-core (and 4-core) evaluation returns all-zero; 2-core is clean.
# T1 (tag truncation) is refuted: VX_MEM_TAG_WIDTH=9 << 32, no id truncation.
# Socket theory is refuted: 4 cores (1 socket) fails the same as 8 cores (2 sockets).
# So the fault is in the multi-core path (>2 cores / SOCKET_SIZE jumps 2->4).
#
# This post-mortem (SAME WLF, no rerun) answers the next bisection:
#   (A) Did the capture even reach compute + readback?  (vx_busy window)
#   (B) What are the per-core LSU signal names?          (so the next hunt can trace stores)
#   (C) Does DEVICE memory hold the right dest while the HOST reads zero
#       (=> readback/coherence), or is device memory ALSO zero
#       (=> the GPU never stored the right data: compute / task-distribution)?
#
#   vsim -c -view <sim-wave-evaluation-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/hunt-8core.do; quit -f" | tee hunt-8core.log

set GPU /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram
set CPU /testbench/soc/sim_mem_gen/axi_mem_gen/mig_axiram
set VXB /testbench/soc/sys/gpusys/vortex/wrap/vx_busy
set TOP /testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex

set DS ""
catch {set DS [lindex [dataset list] 0]}
if {$DS ne ""} {
  set GPU "${DS}:${GPU}" ; set CPU "${DS}:${CPU}"
  set VXB "${DS}:${VXB}" ; set TOP "${DS}:${TOP}"
}

set LOGF [open "hunt-8core.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }
proc val {sig t} { if {[catch {examine -time ${t}ns -radix hex $sig} r]} { return "<no>" } ; return [string tolower [lindex $r end]] }
proc bit {sig t} { if {[catch {examine -time ${t}ns $sig} r]} { return "?" } ; return [lindex $r end] }

set TEND 25000000   ;# wave-8core.do ran 25 x 1ms; adjust if the WLF is longer

# ---- (A) vx_busy window: 1us coarse scan to bracket compute + tell if the capture
#      reached the readback at all (if vx_busy never falls, the run was too short).
say "=== (A) vx_busy transitions (1us scan, 0..${TEND} ns) ==="
set prev "?"
for {set t 0} {$t <= $TEND} {incr t 1000} {
  set b [bit $VXB $t]
  if {$b ne $prev} { say [format "  t=%9d ns  vx_busy=%s" $t $b] ; set prev $b }
}
say "  (if vx_busy never returns to 0, the test did not finish in the captured window)"

# ---- (B) per-core LSU signal-name discovery (2 sockets x 4 cores). Just lists the
#      store-relevant nets so the follow-up hunt can trace exact addresses/data.
say ""
say "=== (B) per-core LSU signals (for the next store-trace) ==="
for {set s 0} {$s < 2} {incr s} {
  for {set c 0} {$c < 4} {incr c} {
    set CORE "${TOP}/clusters\[0\]/cluster/sockets\[$s\]/socket/cores\[$c\]/core"
    set sigs {}
    catch { set sigs [find signals -r ${CORE}/execute/lsu_unit/*] }
    set hits {}
    foreach g $sigs {
      if {[string match -nocase "*addr*" $g] || [string match -nocase "*req_valid*" $g] || [string match -nocase "*req_rw*" $g] || [string match -nocase "*byteen*" $g]} {
        lappend hits [lindex [split $g /] end]
      }
    }
    say [format "  core s%dc%d : %d lsu signals; store-ish: %s" $s $c [llength $sigs] [join [lrange $hits 0 7] " "]]
  }
}

# ---- (C) device (GPU) vs host (CPU) memory read-data: report every change of each
#      memory's read-back data with its address. Device dout = what the GPU stored;
#      CPU dout = what the host got. Compare.
say ""
say "=== (C) device(GPU) vs host(CPU) read-data, changes @1us ==="
say "      time(ns) | mem | addr        | dout (byte15..byte0)"
say "  -------------+-----+-------------+-----------------------------------"
set pg "" ; set pc ""
for {set t 0} {$t <= $TEND} {incr t 1000} {
  set gd [val ${GPU}/rbout(1).dout $t]
  if {$gd ne $pg && $gd ne "<no>"} { say [format "  %11d | GPU | %-11s | %s" $t [val ${GPU}/rbin(1).addr $t] $gd] ; set pg $gd }
  set cd [val ${CPU}/rbout(1).dout $t]
  if {$cd ne $pc && $cd ne "<no>"} { say [format "  %11d | CPU | %-11s | %s" $t [val ${CPU}/rbin(1).addr $t] $cd] ; set pc $cd }
}
say ""
say "=== verdict guide:"
say "  * device(GPU) dout shows 2*i pattern, host(CPU) dout = 0  -> readback/coherence bug"
say "  * device(GPU) dout is 0/stale across the dest region       -> GPU never stored right"
say "                                                                 (compute / task-distribution)"
close $LOGF
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
