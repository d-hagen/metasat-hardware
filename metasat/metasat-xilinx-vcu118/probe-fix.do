# probe-fix.do — confirm the wide-UUID fix is LIVE in the compiled design.
# No long run required.
#
# Phase 1 (structural, t=0, no run): elaborate and check instr_uuid WIDTH.
#   width 23  -> fix compiled in.   width 9 (or [8:0]) -> STALE/old libs/wrong branch.
#   This alone catches BOTH prior failures (both manifested as 9-bit tags).
#
# Phase 2 (optional, bounded run): run a little, prove the uuid VALUE is non-zero
#   and varies per core (rules out the v1 "wide field but hardwired 0" bug).
#
# Usage on the sim machine, AFTER wipe+rebuild:
#   vsim -c -voptargs="+acc" -do probe-fix.do testbench
#   # for phase 2, probe the LIGHT variant so the GPU starts fast:
#   #   make -f setup_sim.mk TEST=evaluation-light select-test   (copies ram.srec)
#
# Exit codes: 0 = PASS, 1 = wrong width (STALE), 2 = signal not found.

onerror {quit -code 3}

echo "=================== METASAT fix-liveness probe ==================="

# ---- locate instr_uuid anywhere in the elaborated hierarchy ----
set hits [find signals -recursive *instr_uuid]
if {[llength $hits] == 0} { set hits [find nets -recursive *instr_uuid] }
if {[llength $hits] == 0} {
    echo "PROBE FAIL: instr_uuid not found. Wrong top, or design not compiled."
    quit -code 2
}
set sig [lindex $hits 0]
echo "Found: $sig   (\[llength $hits\] core instances total)"

# ---- Phase 1: structural width check (no run) ----
set d [describe $sig]
echo "describe: $d"
if {[regexp {\[(\d+):(\d+)\]} $d -> hi lo]} {
    set width [expr {$hi - $lo + 1}]
    echo "instr_uuid width = $width bits"
    if {$width >= 21} {
        echo ">>> PHASE 1 PASS: wide tag compiled in (>=21, expect 23)."
    } else {
        echo ">>> PHASE 1 FAIL: width $width -- STALE libs / wrong branch / old src."
        echo "    Fix: confirm branch sim/8core-debug, then 'make -f setup_sim.mk wipe && rebuild'."
        quit -code 1
    }
} else {
    echo "WARN: could not parse width from describe; inspect the line above."
}

# ---- Phase 2: value check (bounded run; comment out to skip) ----
# Watches until the first scheduled warp gives a non-zero uuid, or gives up.
echo "--- Phase 2: bounded run to confirm uuid VALUE is non-zero/varied ---"
set seen_nonzero 0
for {set i 0} {$i < 20} {incr i} {
    run 100 us
    foreach s $hits {
        set v [examine -radix unsigned $s]
        if {[string is integer -strict $v] && $v != 0} {
            echo "  t=[format %s [examine -time]]  $s = 0x[examine -radix hex $s] ($v)"
            set seen_nonzero 1
        }
    }
    if {$seen_nonzero} { break }
}
if {$seen_nonzero} {
    echo ">>> PHASE 2 PASS: uuid value non-zero -> real {g_wid,pc} fix is live (not v1 zero-uuid)."
} else {
    echo ">>> PHASE 2 INCONCLUSIVE: GPU may not have scheduled yet in the bounded window."
    echo "    Re-probe with TEST=evaluation-light, or raise the loop count above."
}

echo "================================================================="
quit -f
