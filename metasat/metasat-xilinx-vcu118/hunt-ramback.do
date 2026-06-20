# hunt-ramback.do -- read the dest-line write/read off the GPU memory backing store.
#
# Run against the WLF from a wave-s15 run that logged sim_mem_gen (rbin/rbout):
#   vsim -c -view <sim-wave-evaluation-s15-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/hunt-ramback.do; quit -f" | tee hunt-ramback.log
#
# rbin(1) = what aximem drives INTO ramback: addr (word addr = byteaddr>>4), wr
# (16-bit strobe), din (128-bit). rbout(1) = what ramback returns: dout (128-bit).
# Dest byte addr 0x60008040 -> ramback word addr 0x06000804 (low hex "6000804").
#
# Read-out:
#   * A line with wr=7000 + din bytes 12-14 = 1c/1a/18 at a "...6000804" addr means
#     the remainder store reached memory. If wr=7000 shows a DIFFERENT addr -> the
#     store was mis-routed there.
#   * On the dest read-back, dout byte 12 (the 13th byte from the right) = 18 means
#     the store is visible in memory; 00/UU means it isn't.

set RB   /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram
set DEST 6000804          ;# 0x60008040 >> 4, matched as a hex suffix
set T0   10710000         ;# ns
set T1   10810000         ;# ns  (dest writes ~10.713-10.733ms + read-back ~10.8ms)
set STEP 1                ;# ns

set DS ""
catch {set DS [lindex [dataset list] 0]}
if {$DS ne ""} { set RB "${DS}:${RB}" }

set LOGF [open "hunt-ramback.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }
proc val {sig t {radix hex}} {
    if {[catch {examine -time ${t}ns -radix $radix $sig} r]} { return "<no:$sig>" }
    return [lindex $r end]
}

say "=== gpu_axiram ramback interface, ${T0}..${T1} ns  (dest word addr suffix ...${DEST}) ==="
say "      time(ns) | what                | addr        | wr   | din / dout (128-bit, byte15..byte0)"
say "  -------------+---------------------+-------------+------+-----------------------------------------"

set last_dest ""
set last_w7 ""
for {set t $T0} {$t <= $T1} {incr t $STEP} {
    set addr [val ${RB}/rbin(1).addr $t]
    set wr   [val ${RB}/rbin(1).wr   $t]

    # Any access (write or read) to the dest line -> show wr + din + dout
    if {[string match "*$DEST" $addr]} {
        set sig "$wr|[val ${RB}/rbin(1).din $t]|[val ${RB}/rbout(1).dout $t]"
        if {$sig ne $last_dest} {
            say [format "  %11d | DEST-line access     | %-11s | %-4s | din=%s  dout=%s" \
                  $t $addr $wr [val ${RB}/rbin(1).din $t] [val ${RB}/rbout(1).dout $t]]
            set last_dest $sig
        }
    }

    # Any write with the remainder strobe 0x7000, wherever it is routed
    if {$wr eq "7000"} {
        set sig "$addr|[val ${RB}/rbin(1).din $t]"
        if {$sig ne $last_w7} {
            say [format "  %11d | WRITE strb=7000      | %-11s | 7000 | din=%s" \
                  $t $addr [val ${RB}/rbin(1).din $t]]
            set last_w7 $sig
        }
    }
}
say "=== done. wr=7000 din byte12 should be 18; dest read-back dout byte12 tells if it landed. ==="
close $LOGF
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
