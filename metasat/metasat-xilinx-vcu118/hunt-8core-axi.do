# hunt-8core-axi.do -- did the GPU EMIT the dest writes for cores 0-5?
#
# Finding so far (hunt-8core.log): device dest map after the 8-core eval is
#   words 0x06000840..0600086f (cores 0-5) = mostly ZERO  -> FAIL
#   words 0x06000870..0600087f (cores 6,7) = perfect       -> OK
# So 6 of 8 cores' results never reached device memory. Two possibilities:
#   (P1) the GPU EMITTED correct writes to 0x60008400..0x600086ff but the sim
#        aximem (matches W<->AW by ID, the b5ec44c hazard) DROPPED them
#        -> SIM-ONLY artifact, not the FPGA bug.
#   (P2) the GPU NEVER emitted those writes (cores 0-5 didn't commit stores)
#        -> genuine GPU-side bug, matches the FPGA all-zero.
#
# This traces the GPU AXI write port (gpu_aximo_sim) over the compute window and
# lists every AW beat that targets the dest buffer (0x60008400..0x600087ff), with
# its id, plus per-core-region tallies and W/B beat counts. SAME WLF, no rerun.
#
#   vsim -c -view <sim-wave-evaluation-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/hunt-8core-axi.do; quit -f" | tee hunt-8core-axi.log

set AXO /testbench/soc/gpu_aximo_sim   ;# master->slave: aw.id/addr, w.id/strb/data
set AXI /testbench/soc/gpu_mem_aximi   ;# slave->master: aw.ready, w.ready, b.id/valid

set DS ""
catch {set DS [lindex [dataset list] 0]}
if {$DS ne ""} { set AXO "${DS}:${AXO}" ; set AXI "${DS}:${AXI}" }

set T0   11300000   ;# compute window (vx_busy 11.313..11.507ms) + margin
set T1   11520000
set STEP 1

# dest buffer: byte 0x60008400 .. 0x600087ff (1024 B, 8 cores x 128 B)
set DBASE 1610613248 ; # 0x60008000
set DLO   1610613248 ; catch {set DLO [expr {0x60008400}]}
set DHI   0 ;          catch {set DHI [expr {0x600087ff}]}

set LOGF [open "hunt-8core-axi.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }
proc val {sig t {radix hex}} { if {[catch {examine -time ${t}ns -radix $radix $sig} r]} { return "<no>" } ; return [lindex $r end] }
proc hi {sig t} { if {[catch {examine -time ${t}ns $sig} r]} { return 0 } ; return [string equal [string index [lindex $r end] end] "1"] }

say "=== GPU write port (gpu_aximo_sim) AW beats to the dest buffer, ${T0}..${T1} ns ==="
say "      time(ns) | aw.id              | aw.addr      | core-region (addr-0x60008400)/128"
say "  -------------+--------------------+--------------+----------------------------------"

# per-core-region AW tally + id set
for {set k 0} {$k < 8} {incr k} { set awcnt($k) 0 }
set allids {}
set p_aw 0 ; set wbeats 0 ; set bbeats 0 ; set p_w 0 ; set p_b 0 ; set awtot 0

for {set t $T0} {$t <= $T1} {incr t $STEP} {
    set aw [expr {[hi ${AXO}.aw.valid $t] && [hi ${AXI}.aw.ready $t]}]
    if {$aw && !$p_aw} {
        incr awtot
        set id [val ${AXO}.aw.id $t]
        set a  [val ${AXO}.aw.addr $t]
        set ai 0 ; catch {set ai [expr {"0x$a"}]}
        if {$ai >= $DLO && $ai <= $DHI} {
            set k [expr {($ai - $DLO) / 128}]
            if {$k >= 0 && $k < 8} { incr awcnt($k) }
            say [format "  %11d | %-18s | %-12s | core %d" $t $id $a $k]
            lappend allids $id
        }
    }
    set p_aw $aw

    set w [expr {[hi ${AXO}.w.valid $t] && [hi ${AXI}.w.ready $t]}]
    if {$w && !$p_w} { incr wbeats }
    set p_w $w

    set b [expr {[hi ${AXI}.b.valid $t] && [hi ${AXO}.b.ready $t]}]
    if {$b && !$p_b} { incr bbeats }
    set p_b $b
}

say ""
say "=== summary ==="
say "  total AW beats in window (any addr) : $awtot"
say "  total W  beats in window            : $wbeats"
say "  total B  beats in window            : $bbeats"
say "  AW beats to each core's dest region (128 B each):"
for {set k 0} {$k < 8} {incr k} { say [format "    core %d (0x%08x): %d AW beats" $k [expr {$DLO + $k*128}] $awcnt($k)] }

# id-collision check: do the same ids repeat across the dest AWs?
say ""
set uids [lsort -unique $allids]
say "  distinct AW ids to dest region: [llength $uids] of [llength $allids] beats  -> [join $uids { }]"
say ""
say "=== verdict:"
say "  * AW beats present for cores 0-5 (with correct data downstream) but memory"
say "    stayed zero  -> sim aximem dropped them (by-id W<->AW collision = SIM artifact)."
say "  * NO AW beats for cores 0-5  -> GPU never issued those stores = real GPU bug."
close $LOGF
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
