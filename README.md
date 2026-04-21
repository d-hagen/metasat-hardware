# MetaSat Vortex 2.2 Upgrade Report

**Date:** 2026-04-13
**Author:** Dan Hagen (with Claude Code assistance)
**Status:** Driver code complete. Awaiting synthesis and FPGA validation.

---

## Table of Contents

1. [Background](#1-background)
2. [Scope of the Upgrade](#2-scope-of-the-upgrade)
3. [Phase 1 -- RTL and Build System (Complete)](#3-phase-1----rtl-and-build-system-complete)
4. [Phase 2 -- Driver API Migration (Complete)](#4-phase-2----driver-api-migration-complete)
   - 4.1 [The Buffer-Handle API](#41-the-buffer-handle-api)
   - 4.2 [Memory Functions](#42-memory-functions)
   - 4.3 [Data Transfer Functions](#43-data-transfer-functions)
   - 4.4 [Kernel Launch](#44-kernel-launch)
   - 4.5 [Configuration and Profiling](#45-configuration-and-profiling)
   - 4.6 [Build System Fix](#46-build-system-fix)
   - 4.7 [Compilation Fixes](#47-compilation-fixes)
5. [Current File Status](#5-current-file-status)
6. [API Change Summary](#6-api-change-summary)
7. [Architecture Notes](#7-architecture-notes)
8. [Known Limitations](#8-known-limitations)
9. [Next Steps](#9-next-steps)
10. [Commit History](#10-commit-history)
11. [References](#11-references)

---

## 1. Background

### The MetaSat Platform

MetaSat is a Horizon Europe project developing a high-performance RISC-V SoC for space applications, prototyped on a Xilinx VCU118 FPGA. The platform consists of:

- **CPU:** 4x NOEL-V cores (64-bit RISC-V, dual-issue) @ 100 MHz
- **GPU:** Vortex GPGPU (RISC-V, 32-bit, SIMT architecture)
- **Interconnect:** PULP-based AXI crossbar
- **GPU config:** 1 cluster, 8 cores, 4 warps, 4 threads = 128 hardware threads

The CPU and GPU share physical DDR memory via the AXI crossbar. Communication uses an AXI4-Lite slave interface (MMIO registers for commands) and an AXI4 master interface (memory transfers). There is no DMA -- data moves word-by-word through MMIO commands.

MetaSat runs bare-metal or under RTEMS (a real-time OS prequalified by ESA). There is no filesystem; GPU kernel binaries are embedded in the CPU code using `xxd` and uploaded at runtime via the Vortex driver API.

### Vortex GPGPU

Vortex is an open-source RISC-V-based soft GPU developed at Georgia Tech. It implements a SIMT (Single Instruction Multiple Thread) execution model with hardware warp scheduling, banked register files, and a configurable cache hierarchy. The architecture is described in the MICRO'21 paper (Tine et al., 2021).

Vortex is a full source copy inside MetaSat at `extra/vortex/` -- not a git submodule. BSC developed custom files for SoC integration:
- **AFU shell** (`hw/rtl/afu/soc/axi/`) -- AXI-Lite control + AXI memory mux
- **SOC runtime** (`runtime/soc/`) -- bare-metal driver for NOEL-V host
- **Synthesis flow** (`hw/syn/soc/`) -- GRLIB integration scripts

### Why Upgrade

The old Vortex version in MetaSat was a July 2020 snapshot (pre-2.x). Vortex 2.2 brings:
- Renamed shared memory (SMEM) to local memory (LMEM) to align with OpenCL/CUDA terminology
- Buffer-handle based API (safer, supports sub-buffer offsets and bounds checking)
- Dynamic kernel addresses (multiple kernels can coexist in memory)
- Hardware-managed local memory (no host-side allocation needed)
- Refactored runtime architecture (common utilities split from backend-specific code)
- New pipeline features: ISSUE_WIDTH, SFU units, ZICOND extension support

---

## 2. Scope of the Upgrade

The upgrade was split into two phases:

| Phase | Goal | Status |
|---|---|---|
| Phase 1 | Swap RTL, update BSC AFU for LMEM renames, update build config, compile | **Complete** |
| Phase 2 | Rewrite SOC driver to match 2.2 API, fix build system | **Complete** |
| Synthesis | Generate bitstream for VCU118 | **Not started** |
| FPGA test | Run kernel end-to-end on hardware | **Not started** |
| Toolchain | Switch to 2.2 LLVM (clang-18) | **Not started** |

### Files Changed

| File | Action |
|---|---|
| `extra/vortex/hw/rtl/` (all except `afu/soc/`) | Replaced with upstream 2.2 |
| `extra/vortex/hw/rtl/afu/soc/axi/VX_afu_ctrl.sv` | 1-line SMEM-to-LMEM edit |
| `extra/vortex/runtime/soc/vortex.cpp` | Major rewrite (2.2 API) |
| `extra/vortex/runtime/soc/Makefile` | `utils.o` path fix |
| `extra/vortex/runtime/include/vortex.h` | Replaced with upstream 2.2 |
| `extra/vortex/runtime/common/` | Replaced with upstream 2.2 |
| `extra/vortex/runtime/stub/utils.cpp` | Replaced with upstream 2.2 |
| `extra/vortex/hw/syn/soc/src/` | Regenerated from 2.2 RTL |
| `extra/vortex/config.mk` | Hand-written for local VM build |

### Files NOT Changed

| File | Reason |
|---|---|
| `hw/rtl/afu/soc/axi/vortex_afu.sv` | BSC-custom, no SMEM references |
| `hw/rtl/afu/soc/axi/VX_afu_dma.sv` | BSC-custom, unchanged |
| `hw/rtl/afu/soc/axi/vortex_afu.vh` | BSC-custom, auto-generated |
| `runtime/soc/axictrl.h`, `axictrl.cpp` | BSC AXI controller, unchanged |
| `runtime/soc/baremetal.h` | Bare-metal stubs, unchanged |
| `metasatcore.vhd` | SoC top-level, port map unchanged |

---

## 3. Phase 1 -- RTL and Build System (Complete)

Phase 1 was completed in earlier sessions (March 2026). Summary:

**Step 1.1 -- RTL Swap:** The entire `extra/vortex/` directory was replaced with a clean copy of the Vortex 2.2 repo. BSC-custom directories (`afu/soc/`, `runtime/soc/`, `hw/syn/soc/`) were backed up and restored on top. Verified with `diff -rq`: zero file differences from upstream outside the BSC directories.

**Step 1.2 -- SMEM-to-LMEM Renames:** One line changed in `VX_afu_ctrl.sv`:
- `SM_ENABLED`, `SMEM_LOG_SIZE` replaced with `LMEM_ENABLED`, `LMEM_LOG_SIZE`

**Step 1.3 -- Synthesis Config:** Regenerated `hw/syn/soc/src/` from 2.2 RTL using `gen_sources.sh`. Produced 153 preprocessed files (up from 118 in 2.x). MetaSat config overrides (`NUM_CORES=8`, `STARTUP_ADDR=0x60000000`, etc.) preserved via `ifndef` guards in 2.2's `VX_config.vh`.

**Step 1.4 -- Minimum Driver Changes:** Applied SMEM-to-LMEM renames in `vortex.cpp` for compilation. Replaced the BSC-custom `vortex.h` with the upstream 2.2 header.

**Verification:** RTL sim build + basic regression test passed: 1303 instrs, 12169 cycles, IPC=0.107.

---

## 4. Phase 2 -- Driver API Migration (Complete)

### 4.1 The Buffer-Handle API

The most significant change in Vortex 2.2 is the introduction of opaque buffer handles. The old API returned raw device addresses from allocation functions; the new API wraps addresses in `vx_buffer_h` handles.

**Why this change was made:**

In the old API, callers received a raw `uint64_t` device address from `vx_mem_alloc` and had to track the address, size, and owning device separately. The new API bundles all three into an opaque handle:

```
Old: vx_mem_alloc(device, size, type, &addr)     --> raw uint64_t address
New: vx_mem_alloc(device, size, flags, &hbuffer)  --> opaque buffer handle
```

This was discovered by comparing the 2.2 `vortex.h` header against the old MetaSat API and examining `callbacks.inc` in the upstream runtime, which defines the concrete `vx_buffer` struct used by all backends:

```cpp
struct vx_buffer {
  vx_device* device;   // back-pointer to owning device
  uint64_t addr;       // device-side address
  uint64_t size;       // allocation size
};
```

The `device` back-pointer is essential because `vx_mem_free(hbuffer)` no longer receives the device handle as a parameter -- it extracts it from the buffer. This was identified by examining the new `vx_mem_free` signature which takes only one argument.

**How we implemented it:**

We added the `vx_buffer` struct to `soc/vortex.cpp` (with a forward declaration of `vx_device` since the struct references it before the class is defined), then added internal methods to `vx_device` (`mem_alloc`, `mem_reserve`, `mem_free`) that the extern wrappers call. This two-layer pattern (internal method + extern wrapper) matches the structure in `callbacks.inc` and was adopted because:
1. The extern functions need to create/destroy `vx_buffer` objects
2. The device methods need to be callable through `buffer->device->method()` for rollback paths
3. `vx_mem_free` has no device handle parameter -- it must reach the device through the buffer

### 4.2 Memory Functions

| Function | Change | Why |
|---|---|---|
| `vx_mem_alloc` | `int type` became `int flags`; returns `vx_buffer_h*` instead of `uint64_t*` | `type` (GLOBAL/LOCAL) replaced by `flags` (READ/WRITE/READ_WRITE) because 2.2 moved local memory management to hardware. Host only allocates global memory now. |
| `vx_mem_reserve` | **New function** | Needed by `vx_upload_kernel_bytes` to place kernels at the exact linker-chosen address (e.g. `STARTUP_ADDR`). The old API used a fixed allocation cap at `STARTUP_ADDR`; the new API explicitly reserves the kernel's address range. |
| `vx_mem_free` | Takes `vx_buffer_h` instead of `(device, addr)` | Device extracted from buffer's back-pointer. |
| `vx_mem_address` | **New function** | Extracts the raw device address from a buffer handle. Needed because callers can no longer access the address directly. |
| `vx_mem_access` | **New function (no-op)** | Sets memory protection flags. Required by `vx_upload_kernel_bytes` in `utils.cpp` but has no effect on MetaSat's SOC because there is no MMU or memory protection unit on the AXI path. |
| `vx_mem_info` | Dropped `int type` parameter | Only reports global memory (local is hardware-managed). Also fixed a pre-existing bug in the old code where `allocated()` was written to `*mem_free` instead of `*mem_used` in the local memory branch. |

### 4.3 Data Transfer Functions

| Function | Change | Why |
|---|---|---|
| `vx_copy_to_dev` | `(hdevice, dev_addr, host_ptr, size)` became `(hbuffer, host_ptr, dst_offset, size)` | Buffer handle replaces device+address. `dst_offset` is relative to the buffer start, enabling sub-buffer writes. Added bounds check: `(dst_offset + size) > buffer->size`. |
| `vx_copy_from_dev` | `(hdevice, host_ptr, dev_addr, size)` became `(host_ptr, hbuffer, src_offset, size)` | Same pattern. Parameter order changed to match `memcpy(dst, src, size)` convention. |

The underlying `upload`/`download` methods on `vx_device` are unchanged -- they still do word-by-word MMIO transfers through the AFU's `CMD_MEM_WRITE`/`CMD_MEM_READ` commands.

### 4.4 Kernel Launch

| Function | Change | Why |
|---|---|---|
| `vx_start` | `(hdevice)` became `(hdevice, hkernel, harguments)` | In 2.x, the kernel address was set once during `dcr_initialize` at device open time. In 2.2, `vx_start` writes the kernel and argument addresses to DCRs before each launch, enabling different kernels to be loaded at different addresses. |

The implementation writes four DCR registers before issuing `CMD_RUN`:
- `VX_DCR_BASE_STARTUP_ADDR0/1` -- kernel address (split into two 32-bit writes)
- `VX_DCR_BASE_STARTUP_ARG0/1` -- arguments address (same split)

This was identified by examining `simx/vortex.cpp`'s `start()` method and the `callbacks.inc` `start` lambda, which both follow this pattern.

A local `dcr_initialize` function was also added to `soc/vortex.cpp`. In the old code, this function lived in `common/utils.cpp` (which no longer exists). In 2.2, it's a `static` function in `stub/vortex.cpp`. Since MetaSat's SOC driver compiles separately from the stub, it needed its own copy. The function writes default DCR values at device open time (startup address, zero arguments, MPM class 0).

### 4.5 Configuration and Profiling

| Function | Change | Why |
|---|---|---|
| `vx_dcr_write` | `uint64_t value` became `uint32_t value` | DCR registers are 32-bit wide. Old parameter silently truncated. |
| `vx_dcr_read` | **New function** | Reads from the software DCR cache (`DeviceConfig`). No hardware read -- the AFU has no `CMD_DCR_READ` command. |
| `vx_mpm_query` | **New function (stub, returns 0)** | Required by `vx_dump_perf` in `utils.cpp`. MetaSat's AFU does not expose performance counters via MMIO (no `CMD_MPM_READ` command), so this is a stub that returns zeros. Adding real MPM support would require an RTL change to the AFU. |

The `VX_CAPS_KERNEL_BASE_ADDR` case was removed from `vx_dev_caps` because:
1. The 2.2 `vortex.h` header does not define this constant
2. Its implementation called `dcrs.read(addr)` with the old single-argument signature, which no longer compiles against the new `DeviceConfig::read(addr, &value)` in `common.h`
3. The concept is obsolete -- kernel addresses are now dynamic, set per `vx_start` call

### 4.6 Build System Fix

The SOC Makefile had a path mismatch in the `utils.o` build rule:

```makefile
# Old (2.x) -- correct for 2.x:
$(BUILDIR)/utils.o: ... ../common/utils.cpp
    $(CXX) $(CXXFLAGS) ../common/utils.cpp -c -o $@

# After Phase 1 (broken) -- dependency updated but compile command wasn't:
$(BUILDIR)/utils.o: ... ../stub/utils.cpp
    $(CXX) $(CXXFLAGS) ../common/utils.cpp -c -o $@

# Fixed:
$(BUILDIR)/utils.o: ... ../stub/utils.cpp
    $(CXX) $(CXXFLAGS) ../stub/utils.cpp -c -o $@
```

This reflects the 2.2 reorganization: `utils.cpp` was moved from `common/` to `stub/` as part of the runtime refactoring (upstream commit `c1000f6a3`, May 2024). The shared header content (`DeviceConfig`, `CHECK_ERR`, etc.) was absorbed into `common/common.h`, while the implementation file (`vx_upload_kernel_bytes`, `vx_dump_perf`, etc.) was moved to `stub/utils.cpp` because it only calls the public `vortex.h` API and is backend-agnostic.

### 4.7 Compilation Fixes

| Fix | What | Why |
|---|---|---|
| `ALLOC_MAX_ADDR` undefined | Changed to `GLOBAL_MEM_SIZE - ALLOC_BASE_ADDR` | `ALLOC_MAX_ADDR` was defined in old `utils.h` as `STARTUP_ADDR` to cap the allocator below the kernel region. In 2.2, the allocator covers the full address space and `vx_mem_reserve` in `vx_upload_kernel_bytes` marks the kernel region as used instead. |
| Duplicate `DBGPRINT`/`CHECK_ERR` macros | Removed from `vortex.cpp` | `common.h` (included at line 14) already defines them. The local definitions were functionally identical but caused `-Wmacro-redefined` warnings. |
| Format string mismatches | Fixed `%x`/`%lx` specifiers | `write_register`/`read_register` take `uint64_t` parameters but used `%x` (expects 32-bit). Changed to `%lx`. Also fixed `vx_dcr_write` which used `%lx` after the value parameter was narrowed to `uint32_t`. |
| Extra `NULL` in `DBGPRINT` | Removed | `DBGPRINT("...\n", NULL)` passed an extra argument to a format string with no `%` specifier. |

---

## 5. Current File Status

All upstream-shared files have been verified identical to Vortex 2.2:

| File | Match Status |
|---|---|
| `runtime/include/vortex.h` | Identical to upstream 2.2 |
| `runtime/common/common.h` | Identical to upstream 2.2 |
| `runtime/common/malloc.h` | Identical to upstream 2.2 |
| `runtime/stub/utils.cpp` | Identical to upstream 2.2 |
| `hw/rtl/*` (excluding `afu/soc/`) | Identical to upstream 2.2 |

The SOC driver compiles clean with `-Wall -Wextra` (only `-Wunused-parameter` warnings from stub functions like `vx_mem_access` and `vx_mpm_query`, which is expected).

---

## 6. API Change Summary

```
+------------------+-----------------------------------------------+-----------------------------------------------+
| Function         | Old Signature (2.x)                           | New Signature (2.2)                           |
+------------------+-----------------------------------------------+-----------------------------------------------+
| vx_mem_alloc     | (hdevice, size, int type, uint64_t* addr)     | (hdevice, size, int flags, vx_buffer_h* hbuf) |
| vx_mem_reserve   | (new)                                         | (hdevice, addr, size, flags, vx_buffer_h*)    |
| vx_mem_free      | (hdevice, uint64_t addr)                      | (vx_buffer_h hbuf)                            |
| vx_mem_access    | (new)                                         | (hbuf, offset, size, flags) -- no-op          |
| vx_mem_address   | (new)                                         | (hbuf, uint64_t* addr)                        |
| vx_mem_info      | (hdevice, int type, uint64_t*, uint64_t*)     | (hdevice, uint64_t*, uint64_t*)               |
| vx_copy_to_dev   | (hdevice, dev_addr, host_ptr, size)           | (hbuf, host_ptr, dst_offset, size)            |
| vx_copy_from_dev | (hdevice, host_ptr, dev_addr, size)           | (host_ptr, hbuf, src_offset, size)            |
| vx_start         | (hdevice)                                     | (hdevice, hkernel, harguments)                |
| vx_dcr_write     | (hdevice, addr, uint64_t value)               | (hdevice, addr, uint32_t value)               |
| vx_dcr_read      | (new)                                         | (hdevice, addr, uint32_t* value)              |
| vx_mpm_query     | (new)                                         | (hdevice, addr, core_id, uint64_t*) -- stub   |
+------------------+-----------------------------------------------+-----------------------------------------------+
| vx_dev_open      | unchanged                                     |                                               |
| vx_dev_close     | unchanged                                     |                                               |
| vx_dev_caps      | unchanged (removed VX_CAPS_KERNEL_BASE_ADDR)  |                                               |
| vx_ready_wait    | unchanged                                     |                                               |
+------------------+-----------------------------------------------+-----------------------------------------------+
```

Utility functions (`vx_upload_kernel_bytes`, `vx_upload_kernel_file`, `vx_upload_bytes`, `vx_upload_file`, `vx_dump_perf`, `vx_check_occupancy`) are provided by `stub/utils.cpp` and are identical to upstream 2.2. They are compiled into `utils.o` and linked into `libvortex.a`.

---

## 7. Architecture Notes

### Memory Model

MetaSat's CPU and GPU **share physical DDR memory** via the AXI crossbar. Vortex does not have dedicated GPU RAM. The `MemoryAllocator` in the driver is a software-only data structure running on the CPU that tracks which address ranges are reserved for GPU use. No hardware memory allocation occurs -- the allocator is pure bookkeeping.

```
 NOEL-V CPUs (64-bit)          Vortex GPU (32-bit)
        |                              |
        +---------- AXI Crossbar ------+
                       |
                  Shared DDR
                  (single physical memory)
```

Address ranges:
- `ALLOC_BASE_ADDR` (0x10000) to `GLOBAL_MEM_SIZE` -- GPU allocatable range
- `STARTUP_ADDR` (0x60000000) -- default kernel load address
- `STACK_BASE_ADDR` / `LMEM_BASE_ADDR` (0x7F000000) -- stack and local memory

### Data Transfer Path

All host-to-device transfers go through the AXI-Lite MMIO interface, word-by-word:

```
CPU writes MMIO_CMD_DATA  = <32-bit value>
CPU writes MMIO_CMD_ADDR  = <target address>
CPU writes MMIO_CMD_SIZE  = 4
CPU writes MMIO_CMD_TYPE  = CMD_MEM_WRITE
CPU polls  MMIO_STATUS    until IDLE
(repeat for each 32-bit word)
```

There is no DMA. A 4KB buffer upload requires 1024 MMIO round-trips.

### Kernel Launch Sequence

```
1. vx_upload_kernel_bytes()   -- reserve address, copy binary to device memory
2. vx_upload_bytes()          -- allocate buffer, copy arguments to device memory
3. vx_start(dev, kernel_buf, args_buf)
     |-- DCR write: STARTUP_ADDR0/1 = kernel address
     |-- DCR write: STARTUP_ARG0/1  = arguments address
     |-- MMIO write: CMD_TYPE = CMD_RUN
4. vx_ready_wait()            -- poll STATUS register until IDLE
5. vx_copy_from_dev()         -- read results back
6. vx_mem_free()              -- release buffers
```

---

## 8. Known Limitations

### 8.1 Performance Counters (vx_mpm_query)

`vx_mpm_query` is a stub that returns zeros. The MetaSat AFU command set (`CMD_MEM_READ`, `CMD_MEM_WRITE`, `CMD_RUN`, `CMD_DCR_WRITE`, `CMD_TERMINATE`) does not include a performance counter read command. Implementing real MPM support would require:
1. Adding a new AFU command (e.g. `CMD_MPM_READ`) in the RTL
2. Wiring the memory-mapped MPM region (`IO_MPM_ADDR`) to the MMIO read path
3. Implementing the download logic in `vx_mpm_query`

This is a potential future enhancement, not a blocker.

### 8.2 baremetal.h Host Compile Conflict

`baremetal.h` defines a `nanosleep` function that conflicts with the Linux system declaration when compiling with host `g++`. The `#ifndef __rtems__` guard is inverted -- it includes the file on non-RTEMS systems. This only affects host-side compile testing; the real BSC cross-compiler defines `__rtems__`, skipping the include. Workaround: pass `-D__rtems__` during host compile checks.

### 8.3 Local Memory Allocator

The local memory allocator creation condition (`if (local_mem_size <= 1)`) means the allocator is only created when LMEM is disabled (log_size=0 gives size=1). On MetaSat with `LMEM_LOG_SIZE=14`, `local_mem_size=16384`, so the branch is never entered and the allocator is never created. This is a pre-existing condition from 2.x and has no practical effect since 2.2 moved local memory management to hardware.

---

## 9. Next Steps

### 9.1 RTL Simulation Test

Run the basic regression test through the simulator to confirm the shared runtime code (including `utils.cpp`) works end-to-end with the new API:

```bash
ssh vortex22 'cd /home/dan/metasat-hardware/extra/vortex && \
  ./tests/regression/basic/run_test.sh 2>&1 | tail -5'
```

### 9.2 Cross-Compilation

Build `libvortex.a` with the BSC cross-compiler on their infrastructure:

```bash
cd extra/vortex/runtime/soc && make
```

Requires access to `/mnt/caos_hw/metasat/` (BSC internal, not on this VM).

### 9.3 Synthesis

Generate a VCU118 bitstream:

```bash
make metasat-synth
```

Check: timing closure at 100 MHz, resource utilization (expect slight increase from 2.2's ISSUE_WIDTH and SFU additions).

### 9.4 FPGA Functional Test

Load bitstream onto VCU118 via GRMON, run a test kernel (vecadd or similar). Verify:
- GPU boots (STATUS register goes to IDLE after init)
- Kernel upload succeeds (MMIO write sequence completes)
- Execution produces correct results
- Result readback matches expected output

### 9.5 Toolchain Switch (Separate Effort)

Switch from `riscv-gaisler-elf-g++` (Gaisler's GCC variant) to Vortex 2.2's LLVM toolchain (`clang-18` at `/home/dan/tools/llvm-vortex/`). This enables ZICOND instructions and other 2.2 compiler optimizations. All GPU kernels need rebuilding.

### 9.6 Regression Testing

Run the upstream Vortex test suite configured for MetaSat parameters:

```bash
./tests/regression/basic/run_test.sh
./tests/kernel/hello/run_test.sh
# etc.
```

---

## 10. Commit History

All commits on the `vortex-2.2-upgrade` branch, starting from MetaSat master (`18357a9`):

| Commit | Description |
|---|---|
| `2c1544a` | Phase 1.1: Replace Vortex source 2.x with 2.2 |
| `6986ca6` | Phase 1.3: Update synthesis source directory |
| `9e84191` | Phase 1.4: Restore BSC runtime files, LMEM renames |
| `13b9e31` | Phase 2 clean slate: update vortex.h to 2.2, remove old utils |
| `64e2b8a` | Update utils files |
| `f3fa370` | Memory API updated (vx_buffer, mem_alloc, mem_reserve, mem_free, mem_address, mem_info, copy_to_dev, copy_from_dev) |
| `75994e7` | vx_start updated for dynamic kernel address |
| `18984a7` | Add vx_dcr_read, vx_mem_access, dcr_write uint32_t |
| `88ced03` | Fix compilation: remove VX_CAPS_KERNEL_BASE_ADDR, fix ALLOC_MAX_ADDR, add dcr_initialize, add vx_mpm_query stub |
| `8110bb4` | Remove duplicate macros, fix format strings |

---

## 11. References

1. Tine, B., Elsabbagh, F., Yalamarthy, K., Kim, H. "Vortex: Extending the RISC-V ISA for GPGPU and 3D-Graphics Research." MICRO'21, 2021.
2. Sole i Bonet, M., Wolf, J., Kosmidis, L. "A RISC-V Multicore and GPU SoC Platform with a Qualifiable Software Stack for Safety Critical Systems." arXiv:2502.21027, 2025.
3. Tine, B. et al. "Accelerating Graphic Rendering on Programmable RISC-V GPUs." Hot Chips 2022.
4. Kosmidis, L. et al. "The METASAT Hardware Platform." EDHPC, 2023.
5. Vortex GitHub: https://github.com/vortexgpgpu/vortex
6. MetaSat GitLab: https://gitlab.bsc.es/metasat-public
