#!/usr/bin/env bash
# verify-fix-live.sh — run on the SIM MACHINE from metasat/metasat-xilinx-vcu118/
# Confirms the wide-UUID fix is on the right branch and in the file the sim
# actually compiles, then forces a clean recompile. Bails loudly on the two
# things that made the fix "not stick" before: wrong branch and stale libs.
set -euo pipefail

REPO=${REPO:-../..}                         # metasat-hardware root from the sim dir
SRC="$REPO/extra/vortex/hw/syn/soc/src/VX_schedule.sv"
WANT_BRANCH=sim/8core-debug

bold(){ printf '\033[1m%s\033[0m\n' "$*"; }
fail(){ printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

bold "1) Branch (vortex-2.2-minimal does NOT contain the fix)"
br=$(git -C "$REPO" branch --show-current)
echo "   branch=$br  HEAD=$(git -C "$REPO" rev-parse --short HEAD)"
[ "$br" = "$WANT_BRANCH" ] || fail "on '$br', need '$WANT_BRANCH'. git checkout $WANT_BRANCH && git pull"

bold "2) Real fix present in the file the sim compiles"
[ -f "$SRC" ] || fail "$SRC missing -- src/ not generated/pulled"
grep -q "instr_uuid = '0" "$SRC" && fail "found hardwired instr_uuid='0 -- old/wrong src"
if grep -q "instr_uuid = 23'(w_uuid)" "$SRC"; then
    echo "   OK: instr_uuid = 23'(w_uuid)  (computed, width 23)"
else
    grep -n "instr_uuid" "$SRC" || true
    fail "generated src lacks the real fix (wrong width or zero-uuid)"
fi
grep -q "METASAT-FIX-LIVE" "$SRC" && echo "   OK: runtime liveness \$display present" \
    || echo "   NOTE: no runtime \$display in src (regen may have dropped it; re-add or use probe-fix.do)"

bold "3) Force clean recompile (this is what last time skipped -> stale 9-bit libs)"
make -f setup_sim.mk wipe
make -f setup_sim.mk rebuild

bold "DONE. Verify LIVE without the long run:"
echo "  (a) structural, no run (seconds):"
echo "      vsim -c -voptargs=\"+acc\" -do probe-fix.do testbench"
echo "  (b) or start the run and watch the log head for:"
echo "      [METASAT-FIX-LIVE ...] uuid_width=23 first_uuid=0x<nonzero>   <- live"
echo "      uuid_width=9 / first_uuid=0x0  ->  STALE, Ctrl-C and re-run this script"
