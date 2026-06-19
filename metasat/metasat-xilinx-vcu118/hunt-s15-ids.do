# hunt-s15-ids.do -- POST-MORTEM confirmation, NO new sim run required.
#
# Confirms the aximem by-ID write-matching collision that drops the size-15
# remainder store, using the WLF already captured by wave-s15.do.
#
# Usage on the sim machine (QuestaSim):
#   vsim -view <the sim-wave-evaluation-s15-*.wlf from the failing run> \
#        -do hunt-s15-ids.do
#   (or interactively:  vsim -view <wlf>   then   do hunt-s15-ids.do )
#
# What to look for in the output:
#   * The W beat with strb=0x7000 (the dest[12..14] remainder store, addr
#     0x60008040) carries some AXI id N.
#   * Around the same time there is an outstanding AW to a DIFFERENT address
#     (0x60007540 and/or 0xfffefff0) that ALSO carries id N.
#   That id collision is what lets aximem route the 0x7000 payload (24/26/28)
#   to the wrong AW and a zero payload to dest[12..14] -> readback 0.
#
# The size-15 compute/store burst lives at ~10.71 ms; we scan a tight window
# around the dropped store (t=10715408 ns) to keep this fast.

set AXO  /testbench/soc/gpu_aximo_sim   ;# master->slave: id, addr, strb, data, valid (what aximem sees)
set AXI  /testbench/soc/gpu_mem_aximi   ;# slave->master: aw.ready, w.ready, b.id, b.valid
set NAT  /testbench/soc/gpu_mem_aximo   ;# native Vortex master out (pre-glue ids, for reference)

set T0   10712000   ;# ns
set T1   10720000   ;# ns
set STEP 1          ;# ns; finer than the system clock period, deduped below

# examine a (possibly record-nested) signal at time t, return bare value
proc val {sig t {radix hex}} {
    set r [examine -time ${t}ns -radix $radix $sig]
    # examine may return "{path value}" or just "value"; take the last token
    return [lindex $r end]
}

proc scan_write_port {axo axi nat t0 t1 step} {
    set p_aw 0 ; set p_w 0 ; set p_b 0
    echo "      time(ns) | chan | id                 | addr / strb        | data"
    echo "  -------------+------+--------------------+--------------------+------------------------------------"
    for {set t $t0} {$t <= $t1} {incr t $step} {
        # ---- AW handshake (aw.valid & aw.ready) ----
        set awv [val ${axo}.aw.valid $t bin]
        set awr [val ${axi}.aw.ready $t bin]
        set aw [expr {$awv eq "1" && $awr eq "1"}]
        if {$aw && !$p_aw} {
            echo [format "  %11d |  AW  | %-18s | addr=%-13s |" \
                  $t [val ${axo}.aw.id $t] [val ${axo}.aw.addr $t]]
        }
        set p_aw $aw

        # ---- W handshake (w.valid & w.ready) ----
        set wv [val ${axo}.w.valid $t bin]
        set wr [val ${axi}.w.ready $t bin]
        set w [expr {$wv eq "1" && $wr eq "1"}]
        if {$w && !$p_w} {
            echo [format "  %11d |  W   | %-18s | strb=%-13s | %s" \
                  $t [val ${axo}.w.id $t] [val ${axo}.w.strb $t] [val ${axo}.w.data $t]]
        }
        set p_w $w

        # ---- B handshake (b.valid & b.ready) ----
        set bv [val ${axi}.b.valid $t bin]
        set br [val ${axo}.b.ready $t bin]
        set b [expr {$bv eq "1" && $br eq "1"}]
        if {$b && !$p_b} {
            echo [format "  %11d |  B   | %-18s |                    |" \
                  $t [val ${axi}.b.id $t]]
        }
        set p_b $b
    }
}

echo "=== GPU write-port handshakes, ${T0}..${T1} ns (what aximem sees: gpu_aximo_sim) ==="
scan_write_port $AXO $AXI $NAT $T0 $T1 $STEP
echo "=== done. The strb=0x7000 W beat is dest[12..14]; check its id vs the AW ids to 0x60007540 / 0xfffefff0. ==="
