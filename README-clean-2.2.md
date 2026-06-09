# Metasat × Vortex 2.2 — clean change set

Branch built from `5e6a0a9` (Vortex 2.2 swapped in + LMEM rename done) with only the changes needed to run on the QuestaSim sim env + the diagnostic instrumentation we landed during the eval-light debug session.

## Commits

### 1. `runtime/soc: rewrite for Vortex 2.2 API + dynamic kernel/args via DCRs`
The old Metasat SoC runtime used the 2.x API and a hard-coded kernel address. Rewritten for the 2.2 API (`vx_buffer_h`, `vx_upload_kernel_bytes`, etc.) and to write `STARTUP_ADDR0/1` and `STARTUP_ARG0/1` DCRs from `vx_start(...)` so the kernel buffer can land anywhere the allocator hands back.

### 2. `runtime/common: ALLOC_BASE_ADDR above kernel region (Metasat routing)`
**Root cause of the eval-light hang.** Upstream Vortex defaults the host allocator to `USER_BASE_ADDR = 0x00010000` (works on xrt/opae/PCIe targets — full host address space is GPU-visible). This SoC's GPU master AXI only reaches addresses in the kernel/RAM region (~`0x60000000+`). With the upstream default, `vx_upload_bytes` placed the args buffer at `0x10080`, and the kernel's `csrr mscratch; lw 0(a4)` issued a read that never produced an AR on the master — the LSU back-pressured and warp 0 froze. Moved `ALLOC_BASE_ADDR` to `0x60040000`.

### 3. `hw/rtl/afu: SoC AXI AFU with DMA + state watchdog + AW print log address filter`
The SoC AFU is custom (upstream ships only `opae` and `xrt`). Adds: per-fire AW/AR address logging split into two budgets — `0x70xxxxxx` sentinel addresses get a 1024-entry budget, everything else shares 32 entries — so kernel diagnostic writes aren't drowned out by TLS-init memsets. Includes a state watchdog and reset/AXI counter print.

### 4. `hw/syn/soc: pre-generated Vortex RTL sources (1c/4w/4t RV32, no FPU)`
The sim machine has no Verilator. Pre-processed Vortex SystemVerilog (via `gen_sources.sh`) is committed so the sim picks it up directly. Whenever anything under `hw/rtl/` changes, regenerate with `cd extra/vortex/hw/syn/soc && make all` on the VM and commit the result here.

### 5. `kernel/Makefile: switch to vortex-aware LLVM + -fno-builtin-memset/memcpy`
Generic `riscv32-gnu` GCC has no SIMT divergence support: an `if (per-thread cond)` becomes a plain BNEZ, which this RTL collapses to `last_active_tid`'s decision, silently overriding disagreeing threads. Vortex-LLVM emits `vx_split_n` / `vx_join` when `-vortex-branch-divergence=1` is set. Also adds `-fno-builtin-memset -fno-builtin-memcpy` to stop clang from recognising the byte-loop body of `__wrap_memset`/`__wrap_memcpy` as a memset/memcpy idiom and replacing it with a self-recursive call (`-Wl,--wrap` makes `memset` → `__wrap_memset` → itself, infinite recursion).

### 6. `kernel/vx_start.S: _start phase sentinels + per-thread init markers + __wrap_exit`
Adds single-thread phase sentinels at each step of `_start` (`0x70000300..0x7000031C`), per-thread sentinels at the end of `init_regs_all` (`0x70000400 + mhartid*4`) and `init_tls_all` (`0x70000500 + mhartid*4`), and a `__wrap_exit` that pins warp 0's thread mask stably to 0 on exit. The phase sentinels let you tell exactly which startup step completed without a sim-side debugger.

### 7. `kernel/vx_spawn: branch-free per-thread diagnostics in process_threads`
Replaced the `if (thread_id == 0) { dbg[]=... }` pattern in `process_threads`/`process_threads_stub` with per-thread writes to thread-distinct slots, so SIMT divergence collapse can't swallow them.

### 8. `eval: build flags + test kernels (bare/nospawn/spawn1/light) + heap_init`
`eval/common.mk` switches to the LLVM-vortex toolchain. `eval/evaluation/src/` carries four progressively-complex test kernels (`bare` = single instruction, `nospawn` = read args + write result, `spawn1` = one-task spawn, `light` = 16-task spawn) for bisecting. `heap_init.c` exists because the bare-metal sim has no GRMON to initialise the BCC heap pointers.

### 9. `eval/evaluation+memory: pre-built SRECs and host binaries`
The sim machine has no riscv toolchain. SRECs are built on the VM (`make srec-all`) and committed.

### 10. `metasat/vcu118: QuestaSim setup_sim.mk + wave.do + Vortex config inc`
End-to-end QuestaSim pipeline: UNISIM compile → script gen → libs map → AXI ID-width patches → test SREC selection → RTL compile → sim run. Wave window covers ~20 ms of GPU activity. `vx_config.inc` carries the 1-core/4-warp/4-thread RV32 no-FPU configuration that the pre-generated sources are built for.

### 11. `scripts: regenerate artifacts helper`
Convenience for the VM workflow: regenerates Vortex syn sources, runtime headers, and libs after a config change.

## Current state

| Phase | Status |
|---|---|
| `_start` phases (S1–S8 sentinels) | All firing in bare/nospawn/spawn1/light |
| Worker `init_regs_all` / `init_tls_all` sentinels (R, T) | All firing |
| `kernel.c::main` entered (`[A1]` sentinel) | Should fire after commit 2 lands |
| `vx_spawn_threads` runs to completion | To verify after sim re-run |
| `process_threads` per-thread sentinels (B/Bw/Bp/C/Cs/Ce/D) | To verify |
| Worker stub `[E]` sentinel | To verify |
| `vx_busy` falls cleanly | To verify |

Bare and earlier minimal variants are known to pass. Eval-light's hang was caused by the `lw 0(mscratch)` reading from `0x10080` (not GPU-routable). Fix in commit 2; expected to fully pass on next sim.

## Re-running

```bash
# VM (build):
cd extra/vortex/runtime/soc && make
cd extra/vortex/eval/evaluation && make srec-all
git commit -am "rebuild SRECs"
git push github clean-v2.2

# Sim machine:
git pull github clean-v2.2
make -f setup_sim.mk rebuild
make -f setup_sim.mk TEST=evaluation-light run-sim
```

## Sentinel address map (kernel-side diagnostic writes)

| Address | Marker | Where |
|---|---|---|
| `0x70000000..08` | `[A1] [A2] [A3]` | `kernel.c::main` (eval-light) |
| `0x70000300..1C` | `[S1..S8]` | `_start` phase markers (single-thread) |
| `0x70000400 + mhartid*4` | `[R]` | end of `init_regs_all` |
| `0x70000500 + mhartid*4` | `[T]` | end of `init_tls_all` |
| `0x70000040 + slot*4` | `[B]` | entered `process_threads` |
| `0x70000080 + slot*4` | `[Bw]` | `targs->warp_batches` readback |
| `0x700000C0 + slot*4` | `[Bp]` | `targs` pointer readback |
| `0x70000100 + slot*4` | `[C]` | reached for-loop |
| `0x70000140 + slot*4` | `[Cs]` | per-thread `start_task_id` |
| `0x70000180 + slot*4` | `[Ce]` | per-thread `end_task_id` |
| `0x700001C0 + slot*4` | `[D]` | exited for-loop |
| `0x70000200 + slot*4` | `[E]` | `process_threads_stub` about to `vx_tmc_zero` |
| `0x70000120` | `[F00DF00D]` | `__wrap_exit` reached |

`slot = warp_id * NT + thread_id` (range 0..15 for `NW=NT=4`). Sentinels surface in the QuestaSim log as `VX AW S[n]: addr=0x...`.
