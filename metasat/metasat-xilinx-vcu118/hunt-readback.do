# hunt-readback.do -- trace dest from GPU memory through the read-back. SAME WLF, no rerun.
#   vsim -c -view <sim-wave-evaluation-s15-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/hunt-readback.do; quit -f" | tee hunt-readback.log
#
# gpu_axiram holds dest correctly (dout byte12=0x18=24); the test still reads 0,
# so the fault is in the read-back. This dumps, in the read-back window:
#   * ALL gpu_axiram READS  : addr + dout  -- catches a mis-routed read of the
#     bytes-12..14 tail (would read a wrong addr -> 0), and the copy source.
#   * ALL mig_axiram WRITES : addr + din   -- the copy landing in host memory
#     (does the ...1c1a18 = 28/26/24 tail survive, or write 0?).
# Look for where 28/26/24 (1c/1a/18) becomes 00.

set GPU /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram
set CPU /testbench/soc/sim_mem_gen/axi_mem_gen/mig_axiram
set T0  10780000
set T1  10900000
set STEP 1

set DS ""
catch {set DS [lindex [dataset list] 0]}
if {$DS ne ""} { set GPU "${DS}:${GPU}" ; set CPU "${DS}:${CPU}" }

set LOGF [open "hunt-readback.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }
proc val {sig t} {
    if {[catch {examine -time ${t}ns -radix hex $sig} r]} { return "<no>" }
    return [lindex $r end]
}

say "=== read-back trace, ${T0}..${T1} ns ==="
say "      time(ns) | mem | op | addr        | data (byte15..byte0)"
say "  -------------+-----+----+-------------+-----------------------------------"

set pg "" ; set pc ""
for {set t $T0} {$t <= $T1} {incr t $STEP} {
    # every GPU-memory read (copy source / mis-routed tail read)
    if {[val ${GPU}/rbin(1).wr $t] eq "0000"} {
        set ga [val ${GPU}/rbin(1).addr $t]
        set s "$ga|[val ${GPU}/rbout(1).dout $t]"
        if {$s ne $pg} {
            say [format "  %11d | GPU | RD | %-11s | %s" $t $ga [val ${GPU}/rbout(1).dout $t]]
            set pg $s
        }
    }
    # every host-memory write (copy destination)
    set cwr [val ${CPU}/rbin(1).wr $t]
    if {$cwr ne "0000"} {
        set ca [val ${CPU}/rbin(1).addr $t]
        set s "$ca|$cwr|[val ${CPU}/rbin(1).din $t]"
        if {$s ne $pc} {
            say [format "  %11d | CPU | WR | %-11s | wr=%s din=%s" $t $ca $cwr [val ${CPU}/rbin(1).din $t]]
            set pc $s
        }
    }
}
say "=== done. Trace 1c1a18 (28/26/24): present in GPU RD dout? survives into a CPU WR din? ==="
close $LOGF
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
