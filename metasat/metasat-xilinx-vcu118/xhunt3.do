# Phase 3: watch the GPU AXI port around the zeroed icache line fill.
#
# Needs a WLF captured with wave-axi.do. Samples the post-glue request
# record (gpu_aximo_sim) and the aximem response record (gpu_mem_aximi)
# over the window where the icache missed on line 0x60000700
# (REQs at ~4508828/4508858 ns, zero RSP at ~4508938 ns) and prints every
# record change, so the AR address/ID and the R data/ID are visible.
#
# Verdict:
#   R data for the 0x60000700 fill = zeros  -> memory content is zero
#       (upload hole / AFU-ctrl cmd issue) -- check section 2 (rqdbg) too.
#   R data = correct line (...40c306b3...)  -> icache corrupts the fill
#       (2.2 cache/MSHR bug under concurrent same-line misses).
#
# Usage:
#   vsim -c -view <sim-wave-parallel-nowrap-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/xhunt3.do; quit -f" | tee xhunt3.log

if {![info exists W0]}   { set W0   4508700 }
if {![info exists W1]}   { set W1   4509100 }
if {![info exists STEP]} { set STEP 1 }

set REQ /testbench/soc/gpu_aximo_sim
set RSP /testbench/soc/gpu_mem_aximi
set RAW /testbench/soc/gpu_mem_aximo
set GID /testbench/soc/gpu_wr_id

proc exa {t sig} {
    if {[catch {examine -time ${t}ns $sig} v]} { return "<no-signal>" }
    return $v
}

puts "## GPU AXI port records, window ${W0}-${W1} ns (printed on change)"
puts "## REQ = gpu_aximo_sim (aw/w/b/ar/r master out), RSP = gpu_mem_aximi (slave out)"
puts ""
set pq ""; set ps ""
for {set t $W0} {$t <= $W1} {set t [expr {$t + $STEP}]} {
    set q [exa $t $REQ]
    if {$q ne $pq} { puts "[format %8d $t]ns REQ $q"; set pq $q }
    set s [exa $t $RSP]
    if {$s ne $ps} { puts "[format %8d $t]ns RSP $s"; set ps $s }
}

puts ""
puts "## 2. aximem read queue (rqdbg) snapshots across the window"
foreach t [list $W0 [expr {($W0+$W1)/2}] $W1] {
    puts "rqdbg @${t}ns: [exa $t /testbench/soc/sim_mem_gen/gpu_mem_gen/gpu_axiram/rqdbg]"
}

puts ""
puts "## 3. glue write-ID counter across the window (sanity)"
foreach t [list $W0 $W1] {
    puts "gpu_wr_id @${t}ns: [exa $t $GID]"
}
