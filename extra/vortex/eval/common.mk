# NOEL-V Compiler (Gaisler/Sparrow toolchain; expected on PATH)
GCC_PREFIX ?= riscv-gaisler-elf-
CXX = $(GCC_PREFIX)g++
CC  = $(GCC_PREFIX)gcc
OD  = $(GCC_PREFIX)objdump
CP  = $(GCC_PREFIX)objcopy

# Detect XLEN
XLEN := $(shell $(CC) -dM -E - < /dev/null | grep __SIZEOF_POINTER__ | awk '{print $$3 * 8}')
#XLEN ?= 64
ELF_CLASS = elf$(XLEN)-littleriscv

# Compiler flags
CXXFLAGS += -I$(IDIR) -I$(BDIR) -O$(OFLAG) $(ARGS)
CFLAGS += -I$(IDIR) -I$(BDIR) -O$(OFLAG) $(ARGS)

# Capture our own location for relative-path defaults
EVAL_COMMON_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Vortex Compiler. RISCV_TOOLCHAIN_PATH defaults to the VM path used to build
# Metasat SRECs; override via env / make var to change.
RISCV_TOOLCHAIN_PATH ?= /home/dan/tools/riscv32-gnu-toolchain
RISCV_PREFIX = riscv32-unknown-elf

# Vortex-aware LLVM toolchain (default ON). See kernel/Makefile for the
# rationale -- generic GCC mis-compiles SIMT-divergent branches in this RTL.
VX_USE_LLVM ?= 1
ifeq ($(VX_USE_LLVM),1)
LLVM_VORTEX   ?= /home/dan/tools/llvm-vortex
RISCV_SYSROOT ?= $(RISCV_TOOLCHAIN_PATH)/$(RISCV_PREFIX)
VX_CC  = $(LLVM_VORTEX)/bin/clang
VX_CXX = $(LLVM_VORTEX)/bin/clang++
VX_DP  = $(LLVM_VORTEX)/bin/llvm-objdump
VX_CP  = $(LLVM_VORTEX)/bin/llvm-objcopy
VX_CFLAGS += --sysroot=$(RISCV_SYSROOT) --gcc-toolchain=$(RISCV_TOOLCHAIN_PATH)
VX_CFLAGS += -Xclang -target-feature -Xclang +vortex -mllvm -vortex-branch-divergence=1
VX_CFLAGS += -march=rv32imaf -mabi=ilp32f
# Prevent clang from recognising the byte-loop in __wrap_memset/__wrap_memcpy
# as a memset/memcpy idiom and replacing the body with a call to those
# symbols -- which, under -Wl,--wrap=memset/memcpy, resolves back to the
# wrapper itself, producing an infinite self-recursion. Eval-light hung
# inside this recursion (non-empty .tbss -> n=28 -> body taken).
VX_CFLAGS += -fno-builtin-memset -fno-builtin-memcpy
else
VX_CC  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-gcc
VX_CXX = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-g++
VX_DP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objdump
VX_CP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objcopy
endif
VXBIN  = python3 $(VORTEX_KN_PATH)/scripts/vxbin.py

# Resolved from this file's location (extra/vortex/eval/common.mk → ../kernel, ../runtime)
VORTEX_KN_PATH ?= $(abspath $(EVAL_COMMON_DIR)/../kernel)
VORTEX_RT_PATH ?= $(abspath $(EVAL_COMMON_DIR)/../runtime)

# VX compiler flags
VX_XLEN = 32
VX_STARTUP_ADDR = 0x60000000
VX_CFLAGS += -O$(OFLAG) -std=c++17
VX_CFLAGS += -mcmodel=medany -fno-rtti -fno-exceptions -nostartfiles -fdata-sections -ffunction-sections
VX_CFLAGS += -I$(VORTEX_KN_PATH)/include -I$(VORTEX_KN_PATH)/../hw -I$(VORTEX_RT_PATH)/soc -I$(IDIR)
VX_CFLAGS += -DNDEBUG -DACCEL_=vortex

VX_LDFLAGS += -Wl,-Bstatic,--gc-sections,-T,$(VORTEX_KN_PATH)/scripts/link$(VX_XLEN).ld,--defsym=STARTUP_ADDR=$(VX_STARTUP_ADDR) $(VORTEX_KN_PATH)/libvortexrt.a

# Directories
SDIR := src
IDIR := $(SDIR)/include

BDIR := build
ODIR ?= .

BDIR_CPU := $(BDIR)/cpu
BDIR_GPU := $(BDIR)/gpu

OBJ = $(addprefix $(BDIR_CPU)/, $(patsubst %,%.o, $(basename $(notdir $(SRC)))))
VX_OBJ = $(addprefix $(BDIR_GPU)/, $(patsubst %,%.vx, $(basename $(notdir $(VX_SRC)))))

### RULES
# Rule to create the build directory
$(BDIR):
	@mkdir -p $(BDIR)/cpu $(BDIR)/gpu

# Pattern rule to compile .c files
$(BDIR_CPU)/%.o: $(SDIR)/%.c | $(BDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Pattern rule to compile .cpp files
$(BDIR_CPU)/%.o: $(SDIR)/%.cpp | $(BDIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Rule to create executable
$(TEST)-$(MAKECMDGOALS): $(VX_OBJ) $(OBJ)
	$(CXX) $(CXXFLAGS) $(OBJ) $(VX_OBJ) $(LDFLAGS) -o $(ODIR)/$@
	$(OD) $(ODIR)/$@ -DC | sed -n '/\.debug_aranges>:/q;p' > $(BDIR)/$@.dump

### VX kernel rules
%.vx: %.bin
	$(CP) -I binary -O $(ELF_CLASS) \
	    --redefine-sym _binary_$(subst .,_,$(subst /,_,$<))_start=vx_$(notdir $*)_start \
	    --redefine-sym _binary_$(subst .,_,$(subst /,_,$<))_end=vx_$(notdir $*)_end \
            $< $@

%.bin: %.elf
	OBJCOPY=$(VX_CP) $(VXBIN) $< $@

%.elf: $(VX_SRC) | $(BDIR)
	$(VX_CXX) $(VX_CFLAGS) $(VX_SRC) $(VX_LDFLAGS) -o $@

### Clean rules
clean:
	rm -rf $(BDIR)

clean-all: clean
	rm -rf $(ODIR)/$(TEST)*
