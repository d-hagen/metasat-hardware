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

  # initialize per-thread registers
  csrr  t0, VX_CSR_NUM_WARPS  # get num warps
  la    t1, init_regs_all
  .insn r RISCV_CUSTOM0, 1, 0, x0, t0, t1  # wspawn t0, t1
  li    t0, -1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0
  jal   init_regs
  li    t0, 1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0

  # initialize TLS for all warps
  csrr  t0, VX_CSR_NUM_WARPS  # get num warps
  la    t1, init_tls_all
  .insn r RISCV_CUSTOM0, 1, 0, x0, t0, t1  # wspawn t0, t1
  li    t0, -1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0
  call  __init_tls
  li    t0, 1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0

  # clear BSS segment
  la    a0, _edata
  la    a2, _end
  sub   a2, a2, a0
  li    a1, 0
  call  memset

  # initialize trap vector
  # la t0, trap_entry
  # csrw mtvec, t0

#ifdef HAVE_INITFINI_ARRAY
  # run global initialization functions
  call  __libc_init_array
#endif

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

# newlib's exit() iterates atexit handlers then tail-calls _exit. Without
# this override, libgloss provides an _exit that does ecall + infinite spin,
# hanging the warp. Provide the GPU semantic: deactivate the warp.
.section .text
.type _exit, @function
.global _exit
_exit:
  call vx_perf_dump
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # tmc x0

# Polling barrier: spin until only warp 0 is active. Used by vx_spawn_threads
# to wait for wspawn'd workers to deactivate themselves via vx_tmc_zero.
.section .text
.type vx_wspawn_wait, @function
.global vx_wspawn_wait
vx_wspawn_wait:
  csrr  t0, VX_CSR_ACTIVE_WARPS
  li    t1, 1
  bne   t0, t1, vx_wspawn_wait
  ret

# Replacement for newlib's exit() reached via -Wl,--wrap=exit. Vortex cannot
# deactivate warp 0 (active_warps cannot go below 1), but vx_busy is gated
# on active threads. If warp 0's PC walks through any path containing a tmc
# with non-zero mask (e.g. _start's tmc(1) at 0x20), the mask snaps back
# from 0 and vx_busy stays high. This loop locks warp 0 onto two
# instructions whose only tmc has mask=0, so the thread mask stays at 0
# stably and vx_busy falls.
.section .text
.type __wrap_exit, @function
.global __wrap_exit
__wrap_exit:
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # vx_tmc_zero
  j __wrap_exit

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
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # tmc x0
  ret

.section .text
.type init_tls_all, @function
.local init_tls_all
init_tls_all:
  li    t0, -1
  .insn r RISCV_CUSTOM0, 0, 0, x0, t0, x0  # tmc t0
  call  __init_tls
  .insn r RISCV_CUSTOM0, 0, 0, x0, x0, x0  # tmc x0
  ret

.section .data
	.global __dso_handle
	.weak __dso_handle
__dso_handle:
	.long	0
