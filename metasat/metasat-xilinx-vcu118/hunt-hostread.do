# hunt-hostread.do -- find where the test READS the dest array (host or device) and
# what byte 12 is. SAME WLF, no rerun.
#   vsim -c -view <sim-wave-evaluation-s15-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/hunt-hostread.do; quit -f" | tee hunt-hostread.log
#
# gpu_axiram holds dest correct (byte12=0x18=24); the test reads 0. Write strobes
# are zero-time delta pulses (unsampleable), but READS hold their data, so we find
# the dest value by its signature in any read response. Correct dest line is
#   00 1C 1A 18 16 14 12 10 0E 0C 0A 08 06 04 02 00
# so any read returning the dest contains the substring "0a080604" (bytes 5..2 =
# 10,8,6,4) and "16141210" (bytes 11..8 = 22,20,18,16). We print every GPU- and
# host-memory read whose dout carries that signature -- and show its tail bytes
# (12..14). A read with the head right but the tail = 00 is the corrupted copy
# the test sees.

set GPU /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram
set CPU /testbench/soc/sim_mem_gen/axi_mem_gen/mig_axiram
set T0  10780000
set T1  11100000
set STEP 1

set DS ""
catch {set DS [lindex [dataset list] 0]}
if {$DS ne ""} { set GPU "${DS}:${GPU}" ; set CPU "${DS}:${CPU}" }

set LOGF [open "hunt-hostread.log" w]
proc say {s} { global LOGF; puts $LOGF $s; puts $s }
proc val {sig t} {
    if {[catch {examine -time ${t}ns -radix hex $sig} r]} { return "<no>" }
    return [string tolower [lindex $r end]]
}
proc isdest {d} { return [expr {[string match "*0a080604*" $d] || [string match "*16141210*" $d]}] }

say "=== dest-signature reads, ${T0}..${T1} ns ==="
say "      time(ns) | mem | addr        | dout (byte15..byte0)   <- tail = bytes 14/13/12"
say "  -------------+-----+-------------+-------------------------------------------------"

set pg "" ; set pc ""
for {set t $T0} {$t <= $T1} {incr t $STEP} {
    set gd [val ${GPU}/rbout(1).dout $t]
    if {[isdest $gd] && $gd ne $pg} {
        say [format "  %11d | GPU | %-11s | %s" $t [val ${GPU}/rbin(1).addr $t] $gd]
        set pg $gd
    }
    set cd [val ${CPU}/rbout(1).dout $t]
    if {[isdest $cd] && $cd ne $pc} {
        say [format "  %11d | CPU | %-11s | %s" $t [val ${CPU}/rbin(1).addr $t] $cd]
        set pc $cd
    }
}
say "=== done. Correct tail = ..1C1A18..; corrupted = ..000000.. at the same head. ==="
close $LOGF
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
