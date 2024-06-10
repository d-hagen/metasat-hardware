PROJECT = basic

SRCS = main.cpp

VX_SRCS = kernel.cpp ../../../kernel/src/vx_perf.c start.S

OPTS ?= -n256

include ../common.mk

VX_LDFLAGS = -Wl,-Bstatic,--gc-sections,-T,$(VORTEX_KN_PATH)/linker/vx_link$(XLEN).ld,--defsym=STARTUP_ADDR=$(STARTUP_ADDR)

RISCV_TOOLCHAIN_PATH = /home/msole/metasat/software/tools/compiler/riscv-vortex-toolchain
RISCV_PREFIX = riscv32-unknown-elf

VX_CC  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-gcc
VX_CXX = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-g++
VX_DP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objdump
VX_CP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objcopy

ARG_T ?= 1
ARG_N ?= 1

CXXFLAGS += -DARG_T=$(ARG_T) -DARG_N=$(ARG_N) -DNFILESYS
