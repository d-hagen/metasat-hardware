ROOT_DIR := $(realpath ..)
include $(ROOT_DIR)/config.mk

ifeq ($(XLEN),64)
CFLAGS += -march=rv64imafd -mabi=lp64d
else
CFLAGS += -march=rv32imaf -mabi=ilp32f
endif

INC_DIR := $(VORTEX_HOME)/kernel/include
SRC_DIR := $(VORTEX_HOME)/kernel/src

# Vortex-aware LLVM toolchain (default ON). Generic riscv32-gnu GCC has no
# divergence handling: an `if (per-thread cond)` compiles to a plain BNEZ,
# and this RTL (VX_alu_int.sv:168) picks the warp's branch decision from
# last_active_tid -- silently overriding threads that disagree. Vortex-LLVM
# emits vx_split_n / vx_join when -vortex-branch-divergence=1 is set.
USE_LLVM ?= 1

ifeq ($(USE_LLVM),1)
LLVM_VORTEX   ?= /home/dan/tools/llvm-vortex
RISCV_SYSROOT ?= $(RISCV_TOOLCHAIN_PATH)/$(RISCV_PREFIX)
LLVM_CFLAGS += --sysroot=$(RISCV_SYSROOT)
LLVM_CFLAGS += --gcc-toolchain=$(RISCV_TOOLCHAIN_PATH)
LLVM_CFLAGS += -Xclang -target-feature -Xclang +vortex -mllvm -vortex-branch-divergence=1

CC  = $(LLVM_VORTEX)/bin/clang
AR  = $(LLVM_VORTEX)/bin/llvm-ar
DP  = $(LLVM_VORTEX)/bin/llvm-objdump
CP  = $(LLVM_VORTEX)/bin/llvm-objcopy
CFLAGS += $(LLVM_CFLAGS)
else
CC  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-gcc
AR  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-gcc-ar
DP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objdump
CP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objcopy
endif

CFLAGS += -O3 -mcmodel=medany -fno-exceptions -fdata-sections -ffunction-sections
CFLAGS += -I$(INC_DIR) -I$(ROOT_DIR)/hw -I$(ROOT_DIR)/runtime/soc
CFLAGS += -DXLEN_$(XLEN)

PROJECT := libvortex

SRCS = $(SRC_DIR)/vx_start.S $(SRC_DIR)/vx_syscalls.c $(SRC_DIR)/vx_print.S $(SRC_DIR)/tinyprintf.c $(SRC_DIR)/vx_print.c $(SRC_DIR)/vx_spawn.c $(SRC_DIR)/vx_serial.S $(SRC_DIR)/vx_perf.c

OBJS = $(addsuffix .o, $(notdir $(SRCS)))

all: $(PROJECT).a $(PROJECT).dump

$(PROJECT).dump: $(PROJECT).a
	$(DP) -D $(PROJECT).a > $(PROJECT).dump

%.S.o: $(SRC_DIR)/%.S
	$(CC) $(CFLAGS) -c $< -o $@

%.c.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(PROJECT).a: $(OBJS)
	$(AR) rcs $@ $^

.depend: $(SRCS)
	$(CC) $(CFLAGS) -MM $^ > .depend;

clean:
	rm -rf *.a *.o *.dump .depend
