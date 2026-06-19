# hunt-s15-ids.do -- POST-MORTEM confirmation, NO new sim run required.
#
# Confirms the aximem by-ID write-matching collision that drops the size-15
# remainder store, using the WLF already captured by wave-s15.do.
#
# Usage (batch, like the xhunt scripts):
#   vsim -c -view <sim-wave-evaluation-s15-*.wlf> \
#        -do "do hunt-s15-ids.do; quit -f" | tee hunt-s15-ids.log
#
# Or interactively in the GUI (it writes the log file itself either way):
#   vsim -view <wlf>     then     do hunt-s15-ids.do
#
# What to look for in the output:
#   * The W beat with strb=0x7000 (the dest[12..14] remainder store, addr
#     0x60008040) carries some AXI id N.
#   * Around the same time an outstanding AW to a DIFFERENT address
#     (0x60007540 and/or 0xfffefff0) also carries id N.
#   That id collision is what lets aximem route the 0x7000 payload (24/26/28)
#   to the wrong AW and a zero payload to dest[12..14] -> readback 0.

set AXO  /testbench/soc/gpu_aximo_sim   ;# master->slave: aw.id/addr, w.id/strb/data, valid, b.ready
set AXI  /testbench/soc/gpu_mem_aximi   ;# slave->master: aw.ready, w.ready, b.id, b.valid

set T0   10712000   ;# ns  (size-15 dest-store burst is ~10.71 ms)
set T1   10720000   ;# ns
set STEP 1          ;# ns; finer than the system clock, deduped on transition

# ---- dual output: transcript AND a log file in the launch dir ----
set LOGF [open "hunt-s15-ids.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }

# examine a (possibly record-nested) signal at time t; return bare value
proc val {sig t {radix hex}} {
    if {[catch {examine -time ${t}ns -radix $radix $sig} r]} { return "<no-sig:$sig>" }
    return [lindex $r end]   ;# examine may return "{path value}"; take last token
}
# true if a 1-bit signal is asserted at time t
proc hi {sig t} {
    if {[catch {examine -time ${t}ns $sig} r]} { return 0 }
    return [string equal [string index [lindex $r end] end] "1"]
}

say "=== GPU write-port handshakes, ${T0}..${T1} ns (what aximem sees: gpu_aximo_sim) ==="
say "      time(ns) | chan | id                 | addr / strb        | data"
say "  -------------+------+--------------------+--------------------+------------------------------------"

set p_aw 0 ; set p_w 0 ; set p_b 0
for {set t $T0} {$t <= $T1} {incr t $STEP} {
    # AW handshake (aw.valid & aw.ready)
    set aw [expr {[hi ${AXO}.aw.valid $t] && [hi ${AXI}.aw.ready $t]}]
    if {$aw && !$p_aw} {
        say [format "  %11d |  AW  | %-18s | addr=%-13s |" \
              $t [val ${AXO}.aw.id $t] [val ${AXO}.aw.addr $t]]
    }
    set p_aw $aw

    # W handshake (w.valid & w.ready)
    set w [expr {[hi ${AXO}.w.valid $t] && [hi ${AXI}.w.ready $t]}]
    if {$w && !$p_w} {
        say [format "  %11d |  W   | %-18s | strb=%-13s | %s" \
              $t [val ${AXO}.w.id $t] [val ${AXO}.w.strb $t] [val ${AXO}.w.data $t]]
    }
    set p_w $w

    # B handshake (b.valid & b.ready)
    set b [expr {[hi ${AXI}.b.valid $t] && [hi ${AXO}.b.ready $t]}]
    if {$b && !$p_b} {
        say [format "  %11d |  B   | %-18s |                    |" $t [val ${AXI}.b.id $t]]
    }
    set p_b $b
}

say {=== done. The strb=0x7000 W beat is dest[12..14]; check its id vs the AW ids to 0x60007540 / 0xfffefff0. ===}
close $LOGF
echo "hunt-s15-ids: wrote [file join [pwd] hunt-s15-ids.log]"
