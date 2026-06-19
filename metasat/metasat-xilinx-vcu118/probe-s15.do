# probe-s15.do -- one-shot DIAGNOSTIC against the existing size-15 WLF.
# Reveals the exact signal-path convention (dataset prefix, record-field
# separator) AND dumps the whole AXI write-port records at the three known
# store times, so we can read ids/addr/strb directly if the field scan needs
# a tweak. No sim rerun.
#
# Usage (batch; tee to a SEPARATE file so nothing collides):
#   vsim -c -view <sim-wave-evaluation-s15-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/probe-s15.do; quit -f" | tee probe-s15.log

set BASE /testbench/soc/gpu_aximo_sim
set BAS2 /testbench/soc/gpu_mem_aximi
set T    10715408   ;# the dropped remainder store (strb 0x7000 -> 0x60008040)

proc try {label cmd} {
    if {[catch {uplevel 1 $cmd} r]} { echo "  $label -> ERR: $r" } else { echo "  $label -> $r" }
}

echo "############ 0. datasets ############"
try "dataset list" {dataset list}

echo "############ 1. exact signal names under gpu_aximo_sim ############"
try "find signals -r ${BASE}/*"   "find signals -r ${BASE}/*"
try "find signals -r ${BASE}.*"   "find signals -r ${BASE}.*"
try "find signals ${BASE}"        "find signals ${BASE}"

echo "############ 2. which field separator examines cleanly at T=${T}ns ############"
try "DOT   ${BASE}.w.strb"  "examine -time ${T}ns -radix hex ${BASE}.w.strb"
try "SLASH ${BASE}/w/strb"  "examine -time ${T}ns -radix hex ${BASE}/w/strb"
try "DOT   ${BASE}.w.valid" "examine -time ${T}ns ${BASE}.w.valid"
try "SLASH ${BASE}/w/valid" "examine -time ${T}ns ${BASE}/w/valid"

echo "############ 3. whole-record dump at the three store times (fallback data) ############"
foreach t {10713738 10715408 10718238} {
    echo "---- t=${t}ns ----"
    try "gpu_aximo_sim" "examine -time ${t}ns -radix hex ${BASE}"
    try "gpu_mem_aximi" "examine -time ${t}ns -radix hex ${BAS2}"
}

echo "############ done ############"
if {![catch {batch_mode} _bm] && $_bm} { quit -f }
