# hunt-8core-collide.do -- are two memory transactions with the SAME AXI id
# OUTSTANDING AT THE SAME TIME at the GPU port?  (read AND write channels)
#
# Context: the 8-core (and 2c8t, 4c4t) eval fails; it scales with total compute
# units (lanes), not cores. hunt-8core-axi showed only ~20 distinct AXI ids reused
# across cores. The decisive question is whether the GPU issues a 2nd transaction
# with an id while the 1st with that id is still in flight:
#   * READS colliding  -> FATAL on real AXI4 too (R responses route by RID) -> the
#     real FPGA bug is visible at the port (response mis-route).
#   * only WRITES colliding -> order-safe on real AXI4 (FPGA port OK); the sim's
#     by-id aximem drops them, but the FPGA bug is then INTERNAL to the GPU caches
#     (before the port) -> next hunt goes inside (dcache/L2 mem_req tags).
#
# Method: edge-detect each AR/AW accept and R-last/B complete; keep a per-id
# outstanding count; flag whenever a count reaches >=2. SAME WLF, no rerun.
# (Counts clamp at 0 so a transaction opened before T0 can't drive them negative.)
#
#   vsim -c -view <sim-wave-evaluation-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/hunt-8core-collide.do; quit -f" | tee hunt-8core-collide.log

set AXO /testbench/soc/gpu_aximo_sim   ;# master->slave: aw/ar/.id/.addr, w, b.ready, r.ready
set AXI /testbench/soc/gpu_mem_aximi   ;# slave->master: aw/ar.ready, r.id/.last/.valid, b.id/.valid

set DS ""
catch {set DS [lindex [dataset list] 0]}
if {$DS ne ""} { set AXO "${DS}:${AXO}" ; set AXI "${DS}:${AXI}" }

set T0   11300000   ;# compute window (vx_busy 11.313..11.507ms) + margin
set T1   11520000
set STEP 1

set LOGF [open "hunt-8core-collide.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }
proc val {sig t {radix hex}} { if {[catch {examine -time ${t}ns -radix $radix $sig} r]} { return "<no>" } ; return [lindex $r end] }
proc hi {sig t} { if {[catch {examine -time ${t}ns $sig} r]} { return 0 } ; return [string equal [string index [lindex $r end] end] "1"] }

# sanity: do the read-channel nets resolve? (writes already known to resolve)
set arn 0 ; catch {set arn [llength [find signals ${AXO}.ar.valid]]}
say "sanity: ${AXO}.ar.valid resolves to $arn net(s) (if 0, the read-channel path differs -- tell me)"

array set rd {} ; array set wr {} ; array set rdmax {} ; array set wrmax {}
set rdcoll 0 ; set wrcoll 0

say ""
say "=== same-id transactions OUTSTANDING simultaneously at the GPU port, ${T0}..${T1} ns ==="
say "      time(ns) | chan  | id         | outstanding | this addr"
say "  -------------+-------+------------+-------------+-----------"

set p_ar 0 ; set p_rl 0 ; set p_aw 0 ; set p_b 0
for {set t $T0} {$t <= $T1} {incr t $STEP} {
    # ---- READ: AR accept (open) ----
    set ar [expr {[hi ${AXO}.ar.valid $t] && [hi ${AXI}.ar.ready $t]}]
    if {$ar && !$p_ar} {
        set id [val ${AXO}.ar.id $t]
        set c 1 ; if {[info exists rd($id)]} { set c [expr {$rd($id)+1}] }
        set rd($id) $c
        if {![info exists rdmax($id)] || $c > $rdmax($id)} { set rdmax($id) $c }
        if {$c >= 2} { incr rdcoll ; say [format "  %11d | READ  | %-10s | %-11d | %s" $t $id $c [val ${AXO}.ar.addr $t]] }
    }
    set p_ar $ar
    # ---- READ: R last (close) ----
    set rl [expr {[hi ${AXI}.r.valid $t] && [hi ${AXO}.r.ready $t] && [hi ${AXI}.r.last $t]}]
    if {$rl && !$p_rl} {
        set id [val ${AXI}.r.id $t]
        if {[info exists rd($id)] && $rd($id) > 0} { set rd($id) [expr {$rd($id)-1}] }
    }
    set p_rl $rl

    # ---- WRITE: AW accept (open) ----
    set aw [expr {[hi ${AXO}.aw.valid $t] && [hi ${AXI}.aw.ready $t]}]
    if {$aw && !$p_aw} {
        set id [val ${AXO}.aw.id $t]
        set c 1 ; if {[info exists wr($id)]} { set c [expr {$wr($id)+1}] }
        set wr($id) $c
        if {![info exists wrmax($id)] || $c > $wrmax($id)} { set wrmax($id) $c }
        if {$c >= 2} { incr wrcoll ; say [format "  %11d | WRITE | %-10s | %-11d | %s" $t $id $c [val ${AXO}.aw.addr $t]] }
    }
    set p_aw $aw
    # ---- WRITE: B (close) ----
    set b [expr {[hi ${AXI}.b.valid $t] && [hi ${AXO}.b.ready $t]}]
    if {$b && !$p_b} {
        set id [val ${AXI}.b.id $t]
        if {[info exists wr($id)] && $wr($id) > 0} { set wr($id) [expr {$wr($id)-1}] }
    }
    set p_b $b
}

say ""
say "=== summary ==="
say "  READ  same-id collision events (>=2 outstanding) : $rdcoll"
say "  WRITE same-id collision events (>=2 outstanding) : $wrcoll"
say "  max simultaneous outstanding per READ id:"
foreach id [lsort [array names rdmax]] { if {$rdmax($id) >= 2} { say [format "    id %-10s : %d" $id $rdmax($id)] } }
say "  max simultaneous outstanding per WRITE id:"
foreach id [lsort [array names wrmax]] { if {$wrmax($id) >= 2} { say [format "    id %-10s : %d" $id $wrmax($id)] } }
say ""
say "=== verdict:"
say "  * READS collide  -> real AXI4 mis-routes read responses (FPGA bug visible at port)."
say "  * only WRITES collide -> FPGA port order-safe; bug is INTERNAL to GPU caches"
say "                          (next: trace dcache/L2 mem_req tags per lane)."
close $LOGF
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
