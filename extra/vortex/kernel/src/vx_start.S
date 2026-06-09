// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <VX_config.h>
#include <VX_types.h>
#include <newlib.h>
#include "common.h"

.section .init, "ax"
.global _start
.type   _start, @function
_start:

  # Set mtvec to a halt-loop early. If anything in the kernel takes a trap,
  # the trap PC vectors here instead of bouncing back to 0x60000000 (= _start)
  # and producing apparent re-entries. The halt does vx_tmc_zero so the
  # trapping warp dies cleanly instead of generating endless faults.
  la    t0, _vx_trap_halt
  csrw  mtvec, t0

  # _start runs with mask=1 (only thread 0 of warp 0). All sentinels in
  # this function are therefore single-thread writes and land exactly once.
  # Sentinel addresses 0x70000300..0x7000031C are reserved for _start phase
  # markers; per-thread sentinels in init_regs_all/init_tls_all use
  # 0x70000400/0x70000500 indexed by mhartid.
  li    t0, 0x70000300
  li    t1, 0x5511AAAA            # [S1] _start entered
  sw    t1, 0(t0)

  # initialize per-thread registers
  csrr  t0, VX_CSR_NUM_WARPS  # get num warps
  la    t1, init_regs_all
  .insn r RISCV_CUSTOM0, 1, 0, x0, t0, t1  # wspawn t0, t1

  li    t0, 0x70000304
  li    t1, 0x5522AAAA            # [S2] after wspawn init_regs_all
  sw    t1, 0(t0)

  li    t0, -1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0
  jal   init_regs
  li    t0, 1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0

  # Wait for the spawned init_regs_all workers to fully deactivate before
  # issuing the next wspawn. The wspawn itself is is_wstall-gated in the RTL
  # so this is belt-and-suspenders, but it also rules out any case where the
  # pending-wspawn register holds stale wmask/pc across the next issue.
  jal   vx_wspawn_wait

  li    t0, 0x70000308
  li    t1, 0x5533AAAA            # [S3] after main init_regs, back to single thread
  sw    t1, 0(t0)

  # initialize TLS for all warps
  csrr  t0, VX_CSR_NUM_WARPS  # get num warps
  la    t1, init_tls_all
  .insn r RISCV_CUSTOM0, 1, 0, x0, t0, t1  # wspawn t0, t1

  li    t0, 0x7000030C
  li    t1, 0x5544AAAA            # [S4] after wspawn init_tls_all
  sw    t1, 0(t0)

  li    t0, -1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0
  call  __init_tls
  li    t0, 1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0

  # Wait for init_tls_all workers to drain before proceeding to memset / main.
  jal   vx_wspawn_wait

  li    t0, 0x70000310
  li    t1, 0x5555AAAA            # [S5] after main __init_tls, back to single thread
  sw    t1, 0(t0)

  # clear BSS segment
  la    a0, _edata
  la    a2, _end
  sub   a2, a2, a0
  li    a1, 0
  call  memset

  li    t0, 0x70000314
  li    t1, 0x5566AAAA            # [S6] after BSS memset
  sw    t1, 0(t0)

  # initialize trap vector — already set at the top of _start to _vx_trap_halt.

#ifdef HAVE_INITFINI_ARRAY
  # run global initialization functions
  call  __libc_init_array

  li    t0, 0x70000318
  li    t1, 0x5577AAAA            # [S7] after __libc_init_array
  sw    t1, 0(t0)
#endif

  li    t0, 0x7000031C
  li    t1, 0x5588AAAA            # [S8] about to call main
  sw    t1, 0(t0)

  # call main program routine
  call  main

  # call exit routine
  tail  exit
.size _start, .-_start

.section .text
.type _Exit, @function
.global _Exit
_Exit:
  call vx_perf_dump
  li t0, IO_MPM_EXITCODE
  sw a0, 0(t0)
  fence
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # tmc x0

# newlib_s exit() iterates atexit handlers then tail-calls _exit. Without
# this override, libgloss provides an _exit that does ecall + infinite spin,
# hanging the warp. Provide the GPU semantic: deactivate the warp.
.section .text
.type _exit, @function
.global _exit
_exit:
  call vx_perf_dump
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # tmc x0

# Polling barrier: spin until only warp 0 is active. Used by vx_spawn_threads
# and by _start (after each wspawn) to wait for wspawn-targeted workers to
# deactivate themselves via vx_tmc_zero.
.section .text
.type vx_wspawn_wait, @function
.global vx_wspawn_wait
vx_wspawn_wait:
  csrr  t0, VX_CSR_ACTIVE_WARPS
  li    t1, 1
  bne   t0, t1, vx_wspawn_wait
  ret

# Replacement for newlib_s exit() reached via -Wl,--wrap=exit. Warp 0 CAN
# deactivate in v2.2 RTL (active_warps_n[wid] = (tmask != 0), no exclusion
# for wid=0). So vx_tmc_zero alone is enough; the j guard never executes
# because mask=0 disables fetching.
.section .text
.type __wrap_exit, @function
.global __wrap_exit
__wrap_exit:
  li    t0, 0x70000120
  li    t1, 0xF00DF00D
  sw    t1, 0(t0)                            # [F] __wrap_exit reached
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0   # vx_tmc_zero
1:
  j 1b                                       # guard — never executes (mask=0)

# Trap handler sink. Placed in .init (KEEPed by the linker) so --gc-sections
# does not strip it, then the la _vx_trap_halt reference from _start resolves.
.section .init, "ax"
.type _vx_trap_halt, @function
.global _vx_trap_halt
_vx_trap_halt:
  li    t0, 0x70000130
  li    t1, 0xDEADC0DE
  sw    t1, 0(t0)                            # [T] trap taken (per-warp would alias)
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0   # vx_tmc_zero
1:
  j 1b

.section .text
.type init_regs, @function
.local init_regs
init_regs:
  # set global pointer register
  .option push
  .option norelax
  la    gp, __global_pointer
  .option pop

  # set stack pointer register
  LOAD_IMMEDIATE64(sp, STACK_BASE_ADDR)
  csrr  t0, VX_CSR_MHARTID
  sll   t1, t0, STACK_LOG2_SIZE
  sub   sp, sp, t1

  # set thread pointer register
  # use address space after BSS region
  la    t1, __tbss_size
  mul   t0, t0, t1
  la    tp, _end
  add   tp, tp, t0
  ret

.section .text
.type init_regs_all, @function
.local init_regs_all
init_regs_all:
  li    t0, -1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0
  jal   init_regs

  # Per-thread sentinel: every active thread writes its slot to
  # 0x70000400 + mhartid*4 = [R] reached end of init_regs_all.
  # mhartid is unique per (warp,thread) so each store has a distinct address.
  csrr  t0, VX_CSR_MHARTID
  sll   t1, t0, 2
  li    t2, 0x70000400
  add   t2, t2, t1
  li    t3, 0x55AA0000
  or    t3, t3, t0
  sw    t3, 0(t2)

  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # tmc x0
  ret

.section .text
.type init_tls_all, @function
.local init_tls_all
init_tls_all:
  li    t0, -1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0
  call  __init_tls

  # Per-thread sentinel: every active thread writes its slot to
  # 0x70000500 + mhartid*4 = [T] reached end of init_tls_all.
  csrr  t0, VX_CSR_MHARTID
  sll   t1, t0, 2
  li    t2, 0x70000500
  add   t2, t2, t1
  li    t3, 0x55BB0000
  or    t3, t3, t0
  sw    t3, 0(t2)

  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # tmc x0
  ret

.section .data
	.global __dso_handle
	.weak __dso_handle
__dso_handle:
	.long	0
