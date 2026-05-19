# MetaSat Vortex 2.2 Upgrade

Upgrades the Vortex GPGPU inside the MetaSat SoC from a pre-2.x snapshot (July 2020) to Vortex 2.2.

**Status:** Driver code complete. Awaiting synthesis and FPGA validation.

## Platform

- 4x NOEL-V cores (64-bit RISC-V, dual-issue) @ 100 MHz
- Vortex GPGPU (32-bit RISC-V SIMT)
- PULP AXI crossbar, shared DDR, no DMA -- all transfers via MMIO
- Xilinx VCU118 prototype, bare-metal or RTEMS

Vortex lives at `extra/vortex/` as a full source copy (not a submodule). BSC-custom integration: `hw/rtl/afu/soc/axi/` (AXI-Lite + memory mux), `runtime/soc/` (NOEL-V driver), `hw/syn/soc/` (GRLIB scripts).

## What changed

| Area | Change |
|---|---|
| RTL | `extra/vortex/hw/rtl/` replaced with upstream 2.2 (BSC AFU preserved) |
| Renames | SMEM -> LMEM throughout (1-line in `VX_afu_ctrl.sv`) |
| Driver API | `runtime/soc/vortex.cpp` rewritten for 2.2's buffer-handle API |
| Header | `runtime/include/vortex.h` replaced with upstream 2.2 |
| Build | Synthesis sources regenerated; `utils.o` path corrected |

Key API changes:

- Memory: `vx_mem_alloc/free/reserve/access/address/info` now use opaque `vx_buffer_h` instead of raw addresses.
- Transfers: `vx_copy_to_dev` / `vx_copy_from_dev` take a buffer + offset.
- Launch: `vx_start(dev, kernel_buf, args_buf)` -- kernel address is now per-launch (dynamic).
- DCR: `vx_dcr_write` value narrowed to `uint32_t`; new `vx_dcr_read` reads from the software cache.
- New stubs: `vx_mpm_query` (returns 0; AFU has no perf-counter MMIO), `vx_mem_access` (no-op; no MMU).

## Architecture notes

CPU and GPU share physical DDR. The host-side `MemoryAllocator` is pure bookkeeping -- no hardware allocator. Host-to-device transfers go through MMIO word-by-word (e.g. 1024 round-trips for a 4 KB upload).

Address map:

- `0x10000 .. GLOBAL_MEM_SIZE` -- GPU-allocatable
- `0x60000000` -- default kernel load
- `0x7F000000` -- stack and local memory

## Known limitations

- **Performance counters:** `vx_mpm_query` is a stub. The AFU command set has no `CMD_MPM_READ`. Adding it requires an RTL change.
- **Host compile of `baremetal.h`:** the `#ifndef __rtems__` guard is inverted; pass `-D__rtems__` for host compile checks. The BSC cross-compiler sets it automatically.
- **Local memory allocator:** never created (pre-existing 2.x condition); irrelevant since 2.2 moved local memory management to hardware.

## Build / run

Cross-compile the SoC runtime (needs BSC infrastructure at `/mnt/caos_hw/metasat/`):

```
cd extra/vortex/runtime/soc && make
```

Local QuestaSim simulation helper:

```
cd metasat/metasat-xilinx-vcu118
make -f setup_sim.mk all
make -f setup_sim.mk TEST=evaluation-light run-sim
```

See `metasat/metasat-xilinx-vcu118/README.md` for synthesis and the full FPGA flow.

## Next steps

1. End-to-end RTL sim of the eval test programs.
2. Synthesis run on VCU118; verify timing closure at 100 MHz.
3. FPGA functional test (vecadd or similar) via GRMON.
4. Switch GPU kernel toolchain to Vortex 2.2 LLVM (`clang-18`) to enable ZICOND and other 2.2 codegen.

## References

1. Tine et al., "Vortex: Extending the RISC-V ISA for GPGPU and 3D-Graphics Research." MICRO'21.
2. Sole i Bonet et al., "A RISC-V Multicore and GPU SoC Platform with a Qualifiable Software Stack for Safety Critical Systems." arXiv:2502.21027, 2025.
3. Vortex: https://github.com/vortexgpgpu/vortex
