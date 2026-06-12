# Phase 2: catch the icache returning garbage instruction words.
#
# Background (from xhunt.do run on WLF 20260612_183149): decode emits uops
# with op_type='x for PCs 0x60000704/0x60000708 (VX_decode.sv defaults
# op_type/op_args to 'x for unrecognized words). Clean wid/tmask/PC + X op
# fields means the fetched WORD was garbage. This script samples the
# per-core icache bus and the decode stage over the pre-hang window and
# prints every request (addr,tag), every response (word,tag), and every
# decode fire (instr word, PC, op_type), flagging zero/X words.
#
# Usage:
#   vsim -c -view <sim-wave-parallel-nowrap-*.wlf> \
#        -do "do metasat/metasat-xilinx-vcu118/xhunt2.do; quit -f" | tee xhunt2.log
#
# Window/step overridable: vsim ... -do "set W0 4508000ns; do .../xhunt2.do; ..."

if {![info exists W0]}   { set W0   4508600 }  ;# window start (ns, plain int ok)
if {![info exists W1]}   { set W1   4509100 }  ;# window end
if {![info exists STEP]} { set STEP 1 }        ;# sample step in ns

set SOCKET {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket}
set CORE   ${SOCKET}/cores\[0\]/core

set IC_REQV ${SOCKET}/per_core_icache_bus_if\[0\]/req_valid
set IC_REQR ${SOCKET}/per_core_icache_bus_if\[0\]/req_ready
set IC_REQD ${SOCKET}/per_core_icache_bus_if\[0\]/req_data
set IC_RSPV ${SOCKET}/per_core_icache_bus_if\[0\]/rsp_valid
set IC_RSPR ${SOCKET}/per_core_icache_bus_if\[0\]/rsp_ready
set IC_RSPD ${SOCKET}/per_core_icache_bus_if\[0\]/rsp_data
set DEC_V   ${CORE}/decode/decode_if/valid
set DEC_R   ${CORE}/decode/decode_if/ready
set DEC_D   ${CORE}/decode/decode_if/data
set DEC_I   ${CORE}/decode/instr

proc exa {t sig} {
    if {[catch {examine -time ${t}ns $sig} v]} { return "<no-signal>" }
    return $v
}
proc fire {t v r} {
    return [expr {[exa $t $v] eq "1'h1" && [exa $t $r] eq "1'h1"}]
}

puts "## icache req/rsp + decode fires, window ${W0}-${W1} ns, step ${STEP} ns"
puts "## req_data fields: {rw byteen addr atype data tag} -- addr is WORD addr (byte = addr<<2)"
puts "## rsp_data fields: {data tag}"
puts "## decode line:     {uuid wid tmask PC ex_type op_type ...} + raw instr"
puts "## flags: ZERO-WORD = fetched word all zeros, X-OP = decode op_type x"
puts ""

set preq 0; set prsp 0; set pdec 0
for {set t $W0} {$t <= $W1} {set t [expr {$t + $STEP}]} {
    # icache request fire (rising edge of valid&&ready)
    set f [fire $t $IC_REQV $IC_REQR]
    if {$f && !$preq} { puts "[format %8d $t]ns REQ  [exa $t $IC_REQD]" }
    set preq $f

    # icache response fire
    set f [fire $t $IC_RSPV $IC_RSPR]
    if {$f && !$prsp} {
        set d [exa $t $IC_RSPD]
        set flag ""
        if {[string match "*32'h00000000*" $d]} { set flag "   <<< ZERO-WORD" }
        if {[string match -nocase "*x*" $d]}    { append flag "   <<< X-IN-RSP" }
        puts "[format %8d $t]ns RSP  $d$flag"
    }
    set prsp $f

    # decode fire
    set f [fire $t $DEC_V $DEC_R]
    if {$f && !$pdec} {
        set d [exa $t $DEC_D]
        set i [exa $t $DEC_I]
        set flag ""
        # op_type is the 6th field: {uuid wid tmask PC ex_type op_type ...}
        if {[regexp {^\{?\S+ \S+ \S+ \S+ \S+ (\S+)} $d -> op] && [string match -nocase "*x*" $op]} {
            set flag "   <<< X-OP"
        }
        puts "[format %8d $t]ns DEC  instr=$i  $d$flag"
    }
    set pdec $f
}
puts ""
puts "## Interpretation guide:"
puts "##  - Find the DEC line(s) flagged X-OP; note their PC and instr word."
puts "##  - Find the RSP that delivered that word (tag encodes wid) and the REQ"
puts "##    it answers. If REQ addr is correct but RSP word is wrong/zero, the"
puts "##    corruption is inside the icache or below (mem side). Compare the"
puts "##    bad RSP's word against what other warps got for the SAME addr."
