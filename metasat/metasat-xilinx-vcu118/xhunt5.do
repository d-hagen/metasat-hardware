# xhunt5.do -- evaluation(-light) hang-state dumper.
#
# Reads a WLF captured by wave-eval.do (post-sim view mode, no rerun) and
# dumps the discriminating state for the vx_spawn_threads hang:
#   - confirms the hang is static (probes 3 late times)
#   - decodes per-warp PCs + stall/active masks, finds the freeze time
#   - dumps branch resolution, ALU int/muldiv commit handshakes,
#     muldiv unit internals, LSU dispatch handshake, AFU busy/done
#   - flags any X on those nets
#
# Usage:
#   vsim -c -view <sim-wave-evaluation-light-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/xhunt5.do; quit -f" | tee xhunt5.log
#
# Optional time overrides (ns, plain ints):
#   set THANG 5900000  ;# a late time where the hang is established
#   set TSCAN0 1800000 ;# freeze-scan window start
#   set TSCAN1 5900000 ;# freeze-scan window end
#   set SCANSTEP 50000

# wave-eval.do logs the heavy pipeline only from 9 ms onward; upload ends
# ~10.3 ms, stall ~10.5 ms. THANG sits deep in the established stall; the
# freeze scan covers the logged 9..16 ms window.
if {![info exists THANG]}   { set THANG   15000000 }
if {![info exists TSCAN0]}  { set TSCAN0   9000000 }
if {![info exists TSCAN1]}  { set TSCAN1  15900000 }
if {![info exists SCANSTEP]}{ set SCANSTEP  50000 }

set WRAP  {/testbench/soc/sys/gpusys/vortex/wrap}
set CORE  ${WRAP}/vortex_axi/vortex/clusters\[0\]/cluster/sockets\[0\]/socket/cores\[0\]/core
set SCH   ${CORE}/schedule
set ALU   ${CORE}/execute/alu_unit/genblk1\[0\]
set LSU   ${CORE}/execute/lsu_unit

proc exa {t sig} {
    if {[catch {examine -time ${t}ns $sig} v]} { return "<no-signal>" }
    return $v
}
proc hasx {v} { return [string match -nocase *x* $v] }
proc pcbyte {v} {
    # "31'h3000038C" -> 0x60000718 (PC stored as PC[31:1])
    if {[regexp {'h([0-9a-fA-F]+)} $v -> h]} {
        return [format 0x%08x [expr {0x$h * 2}]]
    }
    return $v
}

puts "############################################################"
puts "## 1. Hang confirmation (vx_busy/reset, masks, PCs at 3 late times)"
puts "############################################################"
foreach t [list 4000000 5000000 $THANG] {
    puts "-- t=${t}ns"
    puts "   vx_busy=[exa $t ${WRAP}/vx_busy]  vx_reset=[exa $t ${WRAP}/vx_reset]"
    puts "   active_warps =[exa $t ${SCH}/active_warps]"
    puts "   stalled_warps=[exa $t ${SCH}/stalled_warps]"
    puts "   thread_masks =[exa $t ${SCH}/thread_masks]"
}

puts ""
puts "############################################################"
puts "## 2. Per-warp PC decode at THANG=${THANG}ns"
puts "############################################################"
for {set w 0} {$w < 4} {incr w} {
    set raw [exa $THANG ${SCH}/warp_pcs\[$w\]]
    puts "   warp\[$w\] pc_raw=$raw  byte=[pcbyte $raw]"
}

puts ""
puts "############################################################"
puts "## 3. Activity freeze scan (last change in scan window)"
puts "##    grid ${TSCAN0}..${TSCAN1}ns step ${SCANSTEP}ns"
puts "############################################################"
set sigs [list ${SCH}/active_warps ${SCH}/stalled_warps \
               ${SCH}/warp_pcs\[0\] ${SCH}/warp_pcs\[1\] \
               ${SCH}/warp_pcs\[2\] ${SCH}/warp_pcs\[3\] \
               ${WRAP}/vx_busy]
foreach s $sigs {
    set last "<none>"; set lastt "-"; set prev "__init__"
    for {set t $TSCAN0} {$t <= $TSCAN1} {incr t $SCANSTEP} {
        set v [exa $t $s]
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
    set v [exa $THANG $s]
    set f ""; if {[hasx $v]} { set f "   <<< X" }
    puts "   $s = $v$f"
}
puts "   int_execute_if/data  = [exa $THANG ${ALU}/int_execute_if/data]"

puts ""
puts "############################################################"
puts "## 5. Muldiv unit internals at THANG (X / stuck-valid sweep)"
puts "############################################################"
if {[catch {find signals -r ${ALU}/muldiv_unit/*} ms]} { set ms {} }
if {[llength $ms] == 0} { puts "   (no muldiv_unit signals logged -- was alu_unit logged -r?)" }
foreach s [lsort $ms] {
    set v [exa $THANG $s]
    if {[hasx $v] || [string match -nocase *valid* $s] || [string match -nocase *ready* $s] \
        || [string match -nocase *state* $s] || [string match -nocase *busy* $s]} {
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
    if {[string match -nocase *valid* $s] || [string match -nocase *ready* $s] \
        || [string match -nocase *state* $s]} {
        set v [exa $THANG $s]
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
    set v [exa $THANG $s]
    if {[hasx $v] || [regexp -nocase {state|busy|done|start|cmd|run|idle|ap_} $s]} {
        set f ""; if {[hasx $v]} { set f "   <<< X" }
        puts "   $s = $v$f"
    }
}

puts ""
puts "## Done. Read section 1/3 first: is vx_busy stuck 1, is one warp"
puts "## still active+stalled, and where did activity freeze? Then map the"
puts "## frozen PC against /tmp/eval-kernel.dump (divu/remu ~0x60000384,"
puts "## jalr callback 0x600003a8, vx_join region). Section 4/5 say whether"
puts "## a muldiv commit or an X is the stall; section 7 says whether the"
puts "## pipeline is idle but the AFU never drops busy."
