#!/usr/bin/env bash
#
# Regenerate Vortex synthesis sources, SoC runtime library, and eval test
# binaries on the Vortex 2.2 VM. Then commit + push to the sim/uni-machine
# branch so the sim machine can pull the pre-built artifacts.
#
# Run on the VM:
#   ssh vortex22
#   cd /home/dan/metasat-hardware
#   git checkout sim/uni-machine && git pull
#   bash scripts/regenerate_artifacts.sh
#
# Expected toolchains (must be on PATH or in the locations below):
#   - Verilator                       (for Vortex source generation)
#   - LLVM clang-18 (Vortex compiler) at /home/dan/tools/llvm-vortex
#   - RISC-V GNU toolchain            at /opt/riscv32-gnu-toolchain
#   - Gaisler RISC-V toolchain        on PATH as riscv-gaisler-elf-*

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Sanity: must be on sim/uni-machine
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "sim/uni-machine" ]; then
    echo "ERROR: expected branch 'sim/uni-machine', currently on '$CURRENT_BRANCH'"
    exit 1
fi

echo "=== [1/5] Configure Vortex (writes extra/vortex/config.mk) ==="
(cd extra/vortex && ./configure)

echo "=== [2/5] Regenerate Vortex synthesis sources (hw/syn/soc/src/, sources.txt) ==="
make -C extra/vortex/hw/syn/soc clean
make -C extra/vortex/hw/syn/soc all grlib \
    VX_CONFIG="$REPO_ROOT/metasat/metasat-xilinx-vcu118/vx_config.inc"

echo "=== [3/5] Build SoC runtime library (libvortex.a + generated headers) ==="
make -C extra/vortex/runtime/soc clean
make -C extra/vortex/runtime/soc

echo "=== [4/5] Build eval test SRECs (memory + evaluation, full + light) ==="
for test in memory evaluation; do
    make -C extra/vortex/eval/"$test" clean-all
    make -C extra/vortex/eval/"$test" srec srec-light
done

echo "=== [5/5] Stage + commit + push ==="
git add -A
if git diff --cached --quiet; then
    echo "Nothing to commit — artifacts unchanged."
else
    git commit -m "Regenerate sim artifacts ($(date +%Y-%m-%d_%H:%M:%S))"
    git push origin sim/uni-machine
    echo ""
    echo "=== DONE. Pull on the sim machine:"
    echo "    git checkout sim/uni-machine && git pull"
fi
