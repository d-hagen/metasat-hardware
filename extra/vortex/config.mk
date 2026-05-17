# MetaSat Vortex config.mk - generated for local VM build

VORTEX_HOME ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

XLEN ?= 32

TOOLDIR ?= /home/dan/tools

LLVM_VORTEX ?= $(TOOLDIR)/llvm-vortex

RISCV_TOOLCHAIN_PATH ?= $(TOOLDIR)/riscv$(XLEN)-gnu-toolchain

RISCV_PREFIX  ?= riscv$(XLEN)-unknown-elf
RISCV_SYSROOT ?= $(RISCV_TOOLCHAIN_PATH)/$(RISCV_PREFIX)

VORTEX_RT_PATH ?= $(VORTEX_HOME)/runtime
VORTEX_KN_PATH ?= $(VORTEX_HOME)/kernel

THIRD_PARTY_DIR ?= $(VORTEX_HOME)/third_party
