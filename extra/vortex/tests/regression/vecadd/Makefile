PROJECT = vecadd

SRCS = main.cpp

VX_SRCS = kernel.cpp

OPTS ?= -n16

include ../common.mk

RISCV_TOOLCHAIN_PATH = /workspace/riscv-vortex-toolchain
RISCV_PREFIX = riscv32-unknown-elf

VX_CC  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-gcc
VX_CXX = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-g++
VX_DP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objdump
VX_CP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objcopy

CXXFLAGS += -DARG_N=$(ARG_N) -DNFILESYS
