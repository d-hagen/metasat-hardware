# X-origin hunt for the parallel-nowrap boot stall.
#
# Walks the uop path (operands -> dispatch -> dispatch_unit -> ALU) in a
# post-sim WLF and reports which signals carry X while their valid is 1,
# then bisects each X signal's first-X time. No live sim needed; works on
# any WLF captured by wave.do (issue + alu_unit scopes were logged -r).
#
# Usage (from the repo root or sim dir, on the machine with the WLF):
#   vsim -c -view <sim-wave-parallel-nowrap-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/xhunt.do; quit -f" | tee xhunt.log
#
# Time anchors (override before `do` if your X edge differs):
#   TOK = last known-clean time, TX = first clearly-X time.
#   From WLF 20260612_183149 the ALU X edge is ~4509068 ns.

if {![info exists TOK]} { set TOK 4509000ns }
if {![info exists TX]}  { set TX  4509100ns }
if {![info exists T0 ]} { set T0  4502000ns }  ;# bisect lower bound (pre-hang activity start)

set CORE  {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core}
set SLICE ${CORE}/issue/issue_slices[0]/issue_slice

proc exa {t sig} {
    if {[catch {examine -time $t $sig} v]} { return "<no-signal>" }
    return $v
}

# X detector: unknown bits print as x/X; hex digits never include x.
proc hasx {v} { return [string match -nocase *x* $v] }

# First-X bisect: assumes clean at $lo, X at $hi, X persists once it appears.
proc firstx {sig lo hi} {
    set lo [expr {int([string map {ns {}} $lo])}]
    set hi [expr {int([string map {ns {}} $hi])}]
    while {$hi - $lo > 2} {
        set mid [expr {($lo + $hi) / 2}]
        if {[hasx [exa ${mid}ns $sig]]} { set hi $mid } else { set lo $mid }
    }
    return ${hi}ns
}

puts "############################################################"
puts "## 1. Chain check: where does X enter the uop path?"
puts "##    (clean at TOK=$TOK, X at TX=$TX => corruption inside)"
puts "############################################################"
set chain [list \
    ${SLICE}/scoreboard_if/valid \
    ${SLICE}/scoreboard_if/data \
    ${SLICE}/operands_if/valid \
    ${SLICE}/operands_if/ready \
    ${SLICE}/operands_if/data \
    ${CORE}/execute/alu_unit/per_block_execute_if\[0\]/valid \
    ${CORE}/execute/alu_unit/per_block_execute_if\[0\]/data \
    ${CORE}/execute/alu_unit/genblk1\[0\]/int_execute_if/valid \
    ${CORE}/execute/alu_unit/genblk1\[0\]/int_commit_if/valid \
]
foreach sig $chain {
    set vok [exa $TOK $sig]
    set vx  [exa $TX  $sig]
    set mark ""
    if {[hasx $vx] && ![hasx $vok]} { set mark "  <<< goes X between TOK and TX" }
    puts "=== $sig"
    puts "    @TOK: $vok"
    puts "    @TX : $vx$mark"
}

puts ""
puts "############################################################"
puts "## 2. Sweep: every logged signal in the suspect scopes @TX"
puts "##    (X>> prefix marks signals carrying x; '.' are clean)"
puts "############################################################"
set xsigs {}
foreach scope [list \
    ${SLICE}/dispatch \
    ${SLICE}/operands \
    ${SLICE}/scoreboard \
    ${CORE}/execute/alu_unit/dispatch_unit \
    ${CORE}/execute/alu_unit \
] {
    puts "---- scope: $scope"
    if {[catch {find signals -r $scope/*} sigs]} {
        puts "     (scope not found or nothing logged)"
        continue
    }
    foreach sig [lsort $sigs] {
        set v [exa $TX $sig]
        if {[hasx $v]} {
            puts "X>>  $sig = $v"
            lappend xsigs $sig
        } else {
            puts ".    $sig = $v"
        }
    }
}

puts ""
puts "############################################################"
puts "## 3. First-X times (earliest = closest to the origin)"
puts "############################################################"
set n 0
foreach sig $xsigs {
    if {[incr n] > 60} { puts "(stopping after 60 signals)"; break }
    if {[hasx [exa $T0 $sig]]} {
        puts "ALWAYS-X since $T0: $sig   <-- never initialized? prime suspect"
    } else {
        puts "[firstx $sig $T0 $TX]  $sig"
    }
}
puts ""
puts "## Done. Sort section 3 by time: the earliest first-X signal(s)"
puts "## name the register/RAM where the corruption is born."
