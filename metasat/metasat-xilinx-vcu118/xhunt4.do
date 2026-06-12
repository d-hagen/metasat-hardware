# Phase 4: full write history of the GPU memory port.
#
# xhunt3 verdict: aximem returns all-zeros for the icache fill of line
# 0x60000700 -> the simulated memory really contains zeros there. This
# script reconstructs EVERY write the GPU port ever performed, using the
# sim glue's gpu_wr_id counter (one increment per completed write,
# monotone) to binary-search each write's completion time, then sampling
# the parked AW/W fields one tick before the increment.
#
# Answers:
#   - Did the kernel upload write 0x60000700 at all, and with what data?
#     (expected words: 40c306b3 00000297 005686b3 00c68067)
#   - Did any LATER write hit 0x60000700-0x6000070F (rogue store)?
#
# Usage:
#   vsim -c -view <sim-wave-parallel-nowrap-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/xhunt4.do; quit -f" | tee xhunt4.log
#
# Runtime note: ~2500 writes x ~23 bisect probes -> ~60k examines; let it run.

if {![info exists T0]} { set T0 0 }
if {![info exists T1]} { set T1 4508800 }   ;# counter frozen at 0x9B0 by here

set REQ /testbench/soc/gpu_aximo_sim
set GID /testbench/soc/gpu_wr_id
set RST /testbench/soc/sys/gpusys/vortex/wrap/vx_reset

proc exa {t sig} {
    if {[catch {examine -time ${t}ns $sig} v]} { return "<no-signal>" }
    return $v
}
proc h2i {v} {
    # "32'h000009B0" -> 2480 ; returns -1 on X/garbage
    if {[regexp {'h([0-9a-fA-F]+)$} $v -> h]} { return [expr 0x$h] }
    return -1
}
proc wrid {t} { return [h2i [exa $t $::GID]] }

# earliest time with wrid >= k (counter monotone)
proc tof {k lo hi} {
    while {$hi - $lo > 1} {
        set mid [expr {($lo + $hi) / 2}]
        if {[wrid $mid] >= $k} { set hi $mid } else { set lo $mid }
    }
    return $hi
}

# vx_reset fall time (monotone 1 -> 0)
set lo $T0; set hi $T1
while {$hi - $lo > 1} {
    set mid [expr {($lo + $hi) / 2}]
    if {[exa $mid $RST] eq "1'h0"} { set hi $mid } else { set lo $mid }
}
puts "## vx_reset falls at ~${hi} ns (writes before this = DMA upload, after = Vortex)"
set trst $hi

set NW [wrid $T1]
puts "## total completed writes by ${T1} ns: $NW"
puts "## write#  time(ns)  phase  aw.addr      w.strb   flag/data"
puts ""

set lo $T0
for {set k 1} {$k <= $NW} {incr k} {
    set tk [tof $k $lo $T1]
    set lo $tk                       ;# next bisect starts here (monotone)
    set ts [expr {$tk - 2}]          ;# sample just before the increment
    set r  [exa $ts $::REQ]
    set aw [lindex $r 0]
    set w  [lindex $r 1]
    set addr [lindex $aw 1]
    set strb [lindex $w 2]
    set ai [h2i $addr]
    set phase [expr {$tk < $trst ? "DMA" : "VX "}]
    if {$ai >= 0x60000700 && $ai <= 0x6000070F} {
        puts "[format %6d $k]  [format %9d $tk]  $phase  $addr  $strb  <<< TARGET LINE  wdata=[lindex $w 1]"
    } elseif {$ai >= 0x600006F0 && $ai <= 0x6000071F} {
        puts "[format %6d $k]  [format %9d $tk]  $phase  $addr  $strb  <<< neighbor  wdata=[lindex $w 1]"
    } else {
        puts "[format %6d $k]  [format %9d $tk]  $phase  $addr  $strb"
    }
}
puts ""
puts "## If no TARGET LINE writes exist: upload hole (host/VX_afu_ctrl)."
puts "## If DMA-phase TARGET writes exist with correct data and no later"
puts "## VX-phase write: aximem/glue lost or misplaced them."
puts "## If a VX-phase TARGET write exists: rogue GPU store over code."
