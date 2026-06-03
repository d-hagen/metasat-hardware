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

# VM toolchain locations (override via env if running on a different VM).
# Defaults match the vortex22 host.
export GCC_PREFIX="${GCC_PREFIX:-/home/dan/tools/ncc-1.0.4-gcc/bin/riscv-gaisler-elf-}"
export RISCV_TOOLCHAIN_PATH="${RISCV_TOOLCHAIN_PATH:-/home/dan/tools/riscv32-gnu-toolchain}"
export TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX:-/home/dan/tools/ncc-1.0.4-gcc/bin/riscv-gaisler-elf-}"
export LLVM_VORTEX="${LLVM_VORTEX:-/home/dan/tools/llvm-vortex}"

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
make -C extra/vortex/runtime/soc \
    TOOLCHAIN_PREFIX="$TOOLCHAIN_PREFIX"

echo "=== [4/5] Build eval test SRECs (memory + evaluation, full + light) ==="
# Build order matters: srec-light internally clean-alls (rm -rf gpu-*),
# so build it FIRST. Then clean only the obj dir and build the full-size
# vortex ELF + srec. Final state: both .srec files + SIZE=1024 ELF.
for test in memory evaluation; do
    make -C extra/vortex/eval/"$test" clean-all
    # Light variant first (does its own clean-all + builds at SIZE=16)
    make -C extra/vortex/eval/"$test" srec-light \
        GCC_PREFIX="$GCC_PREFIX" \
        RISCV_TOOLCHAIN_PATH="$RISCV_TOOLCHAIN_PATH"
    # Clean obj dir (preserves .srec/.elf at repo root)
    make -C extra/vortex/eval/"$test" clean
    # Full variant at SIZE=1024
    make -C extra/vortex/eval/"$test" vortex \
        GCC_PREFIX="$GCC_PREFIX" \
        RISCV_TOOLCHAIN_PATH="$RISCV_TOOLCHAIN_PATH"
    make -C extra/vortex/eval/"$test" srec \
        GCC_PREFIX="$GCC_PREFIX" \
        RISCV_TOOLCHAIN_PATH="$RISCV_TOOLCHAIN_PATH"
done

echo "=== [5/5] Stage + commit + push ==="
git add -A
if git diff --cached --quiet; then
    echo "Nothing to commit — artifacts unchanged."
else
    git commit -m "Regenerate sim artifacts ($(date +%Y-%m-%d_%H:%M:%S))"
    # Push to whatever remote sim/uni-machine is tracking (github on the VM)
    git push
    echo ""
    echo "=== DONE. Pull on the sim machine:"
    echo "    git checkout sim/uni-machine && git pull"
fi
