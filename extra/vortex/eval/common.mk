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

# Vortex Compiler
RISCV_TOOLCHAIN_PATH ?= /opt/riscv32-gnu-toolchain
RISCV_PREFIX = riscv32-unknown-elf

VX_CC  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-gcc
VX_CXX = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-g++
VX_DP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objdump
VX_CP  = $(RISCV_TOOLCHAIN_PATH)/bin/$(RISCV_PREFIX)-objcopy
VXBIN  = python3 $(VORTEX_KN_PATH)/scripts/vxbin.py

# Resolved from this file's location (extra/vortex/eval/common.mk → ../kernel, ../runtime)
VORTEX_KN_PATH ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../kernel)
VORTEX_RT_PATH ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../runtime)

# VX compiler flags
VX_XLEN = 32
VX_STARTUP_ADDR = 0x60000000
VX_CFLAGS += -O$(OFLAG) -std=c++17
VX_CFLAGS += -mcmodel=medany -fno-rtti -fno-exceptions -nostartfiles -fdata-sections -ffunction-sections
VX_CFLAGS += -I$(VORTEX_KN_PATH)/include -I$(VORTEX_KN_PATH)/../hw -I$(IDIR)
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
