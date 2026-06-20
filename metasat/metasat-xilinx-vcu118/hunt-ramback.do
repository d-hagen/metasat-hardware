# hunt-ramback.do -- read the dest-line write/read off the GPU memory backing store.
#
# Run against the WLF from a wave-s15 run that logged gpu_axiram/* (rbin/rbout):
#   vsim -c -view <sim-wave-evaluation-s15-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/hunt-ramback.do; quit -f" | tee hunt-ramback.log
#
# rbin = what aximem drives INTO ramback: addr (word addr = byteaddr>>4), wr
# (16-bit strobe), din (128-bit). rbout = what ramback returns: addr, dout.
# The dest cache line is byte 0x60008040 -> ramback word addr 0x06000804.
#
# Decisive read-out:
#   * WRITE side: a rbin beat with wr=0x7000 and din bytes 12-14 = 18/1a/1c at
#     addr 0x06000804 means the remainder store reached the memory.
#   * READ side: when 0x06000804 is read, rbout.dout byte 12 = 0x18 -> the store
#     landed (failure is downstream of memory); 0xUU/0x00 -> it never landed.

set RB   /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram
set DEST 06000804        ;# 0x60008040 >> 4
set T0   10710000        ;# ns
set T1   10745000        ;# ns  (covers compute + the read-back)
set STEP 1               ;# ns

set DS ""
catch {set DS [lindex [dataset list] 0]}
set P ""
if {$DS ne ""} { set P "${DS}:" }
set RB "${P}${RB}"

set LOGF [open "hunt-ramback.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }
proc val {sig t {radix hex}} {
    if {[catch {examine -time ${t}ns -radix $radix $sig} r]} { return "<no:$sig>" }
    return [lindex $r end]
}

say "=== gpu_axiram ramback interface, ${T0}..${T1} ns  (dest word addr = 0x${DEST}) ==="
say "      time(ns) | op  | addr        | wr / dout"
say "  -------------+-----+-------------+-------------------------------------------"

set p_wr "0000"
set p_raddr ""
for {set t $T0} {$t <= $T1} {incr t $STEP} {
    set wr   [val ${RB}/rbin\[1\].wr $t hex]
    set addr [val ${RB}/rbin\[1\].addr $t hex]

    # WRITE: strobe non-zero, print on the cycle it becomes non-zero
    if {$wr ne "0000" && $wr ne $p_wr} {
        say [format "  %11d |  WR | %-11s | wr=%-6s din=%s" \
              $t $addr $wr [val ${RB}/rbin\[1\].din $t hex]]
    }
    set p_wr $wr

    # READ of the dest line: addr matches dest and no write strobe; print dout
    if {$wr eq "0000" && [string match "*$DEST" $addr] && $addr ne $p_raddr} {
        say [format "  %11d | RD  | %-11s | dout=%s" \
              $t $addr [val ${RB}/rbout\[1\].dout $t hex]]
        set p_raddr $addr
    } elseif {![string match "*$DEST" $addr]} {
        set p_raddr ""
    }
}
say "=== done. Look for wr=7000 at addr ..06000804 (write landed?) and the dout on its read. ==="
close $LOGF
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
