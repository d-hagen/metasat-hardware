# xhunt5.do -- evaluation(-light) hang-state dumper.
#
# Reads the state captured by wave-eval.do and dumps the discriminating
# signals for the vx_spawn_threads hang. Works either:
#   - in the SAME vsim session right after Ctrl-C (live, paused), or
#   - on a reopened WLF: vsim -c -view <wlf> -do "do .../xhunt5.do; quit -f"
# In both cases it reads values at the CURRENT/END time (the stall),
# so it does not matter when you stopped the run.
#
#   do metasat/metasat-xilinx-vcu118/xhunt5.do      ;# after Ctrl-C
#   ... | tee xhunt5.log                            ;# (reopened-WLF form)
#
# Overrides: set THANG <ns> to pin a specific time instead of "now".
#            set TSCAN0/TSCAN1/SCANSTEP to retune the freeze scan.

if {![info exists THANG]}   { set THANG   now }       ;# "now" = current/end time
if {![info exists TSCAN0]}  { set TSCAN0   8000000 }  ;# freeze-scan window (ns)
if {![info exists TSCAN1]}  { set TSCAN1  40000000 }
if {![info exists SCANSTEP]} { set SCANSTEP  50000 }

set WRAP  {/testbench/soc/sys/gpusys/vortex/wrap}
set CORE  ${WRAP}/vortex_axi/vortex/clusters\[0\]/cluster/sockets\[0\]/socket/cores\[0\]/core
set SCH   ${CORE}/schedule
set ALU   ${CORE}/execute/alu_unit/genblk1\[0\]
set LSU   ${CORE}/execute/lsu_unit

# point value at the current/end time (THANG=now) or at a pinned ns time
proc pt {sig} {
    global THANG
    if {$THANG eq "now"} {
        if {[catch {examine $sig} v]} { return "<no-signal>" }
    } else {
        if {[catch {examine -time ${THANG}ns $sig} v]} { return "<no-signal>" }
    }
    return $v
}
# value at an absolute ns time (freeze scan)
proc exa {t sig} {
    if {[catch {examine -time ${t}ns $sig} v]} { return "<no-signal>" }
    return $v
}
proc hasx {v} { return [string match -nocase *x* $v] }
proc pcbyte {v} {
    if {[regexp {'h([0-9a-fA-F]+)} $v -> h]} {
        if {[scan $h %x hh] == 1} { return [format 0x%08x [expr {$hh * 2}]] }
    }
    return $v
}

puts "## THANG=$THANG  (now = stall time = current/end of captured data)"
puts ""
puts "############################################################"
puts "## 1. Hang state (vx_busy/reset, masks, PCs) at THANG"
puts "############################################################"
puts "   vx_busy =[pt ${WRAP}/vx_busy]   vx_reset=[pt ${WRAP}/vx_reset]"
puts "   active_warps =[pt ${SCH}/active_warps]"
puts "   stalled_warps=[pt ${SCH}/stalled_warps]"
puts "   thread_masks =[pt ${SCH}/thread_masks]"

puts ""
puts "############################################################"
puts "## 2. Per-warp PC decode at THANG  (map vs /tmp/eval-kernel.dump)"
puts "############################################################"
for {set w 0} {$w < 4} {incr w} {
    set raw [pt ${SCH}/warp_pcs\[$w\]]
    puts "   warp\[$w\] pc_raw=$raw  byte=[pcbyte $raw]"
}

puts ""
puts "############################################################"
puts "## 3. Activity freeze scan (last change), grid ${TSCAN0}..${TSCAN1}ns"
puts "##    (<no-signal> outside the logged window is skipped)"
puts "############################################################"
foreach s [list ${SCH}/active_warps ${SCH}/stalled_warps \
                ${SCH}/warp_pcs\[0\] ${SCH}/warp_pcs\[1\] \
                ${SCH}/warp_pcs\[2\] ${SCH}/warp_pcs\[3\] \
                ${WRAP}/vx_busy] {
    set last "<none>"; set lastt "-"; set prev "__init__"
    for {set t $TSCAN0} {$t <= $TSCAN1} {incr t $SCANSTEP} {
        set v [exa $t $s]
        if {$v eq "<no-signal>"} continue
        if {$v ne $prev} { set lastt $t; set last $v; set prev $v }
    }
    puts "   last change @ ${lastt}ns -> $last    ($s)"
}

puts ""
puts "############################################################"
puts "## 4. Branch resolution + ALU commit handshakes at THANG"
puts "############################################################"
foreach s [list ${SCH}/branch_valid ${SCH}/branch_wid ${SCH}/branch_dest \
                ${ALU}/int_execute_if/valid ${ALU}/int_execute_if/ready \
                ${ALU}/int_commit_if/valid  ${ALU}/int_commit_if/ready \
                ${ALU}/muldiv_commit_if/valid ${ALU}/muldiv_commit_if/ready \
                ${ALU}/muldiv_execute_if/valid ${ALU}/muldiv_execute_if/ready] {
    set v [pt $s]
    set f ""; if {[hasx $v]} { set f "   <<< X" }
    puts "   $s = $v$f"
}
puts "   int_execute_if/data = [pt ${ALU}/int_execute_if/data]"

puts ""
puts "############################################################"
puts "## 5. Muldiv unit internals at THANG (X / valid / ready / state)"
puts "############################################################"
if {[catch {find signals -r ${ALU}/muldiv_unit/*} ms]} { set ms {} }
if {[llength $ms] == 0} { puts "   (no muldiv_unit signals -- was alu_unit logged -r before the stall?)" }
foreach s [lsort $ms] {
    set v [pt $s]
    if {[hasx $v] || [regexp -nocase {valid|ready|state|busy} $s]} {
        set f ""; if {[hasx $v]} { set f "   <<< X" }
        puts "   $s = $v$f"
    }
}

puts ""
puts "############################################################"
puts "## 6. LSU dispatch handshake at THANG (stuck valid/ready?)"
puts "############################################################"
if {[catch {find signals -r ${LSU}/*} ls]} { set ls {} }
foreach s [lsort $ls] {
    if {[regexp -nocase {valid|ready|state} $s]} {
        set v [pt $s]
        set f ""; if {[hasx $v]} { set f "   <<< X" }
        puts "   $s = $v$f"
    }
}

puts ""
puts "############################################################"
puts "## 7. AFU control / busy-done path at THANG"
puts "############################################################"
if {[catch {find signals -r ${WRAP}/afu_ctrl/*} as]} { set as {} }
foreach s [lsort $as] {
    set v [pt $s]
    if {[hasx $v] || [regexp -nocase {state|busy|done|start|cmd|run|idle|ap_} $s]} {
        set f ""; if {[hasx $v]} { set f "   <<< X" }
        puts "   $s = $v$f"
    }
}

puts ""
puts "## Read 1/3 first: is vx_busy stuck 1, is one warp active+stalled,"
puts "## and where did activity freeze? Map the frozen PC against"
puts "## /tmp/eval-kernel.dump (divu/remu ~0x60000384, jalr callback"
puts "## 0x600003a8, vx_join region). 4/5 -> muldiv-commit stall or X;"
puts "## 7 -> pipeline idle but AFU never drops busy."
