CXX = /home/msole/metasat/software/tools/compiler/riscv-sparrow-toolchain/bin/riscv-gaisler-elf-g++
AR = /home/msole/metasat/software/tools/compiler/riscv-sparrow-toolchain/bin/riscv-gaisler-elf-ar
XLEN ?= 32
DESTDIR ?= .
BUILDIR = build
HW_DIR = ../../hw
SYN_DIR = $(HW_DIR)/syn/soc/src

CXXFLAGS += -std=c++11 -Wall -Wextra -pedantic -Wfatal-errors
CXXFLAGS += -I../include -I../common -I.
CXXFLAGS += -DXLEN_$(XLEN)

H_FILES := VX_config.h VX_types.h vortex_afu.h

# Position independent code
#CXXFLAGS += -fPIC

VX_CONFIG = /home/msole/metasat/hardware/metasat/metasat-xilinx-vcu118/vx_config.inc

# Add external configuration
ifneq ("$(wildcard $(VX_CONFIG))","")
    include $(VX_CONFIG)
else
    # Design configuration
    XLEN ?= 32
    NUM_CORES ?= 1

endif
    # cluster configuration
    CONFIGS_1c  := -DNUM_CLUSTERS=1 -DNUM_CORES=1
    CONFIGS_2c  := -DNUM_CLUSTERS=1 -DNUM_CORES=2
    CONFIGS_4c  := -DNUM_CLUSTERS=1 -DNUM_CORES=4
    CONFIGS_8c	:= -DNUM_CLUSTERS=1 -DNUM_CORES=8
    CONFIGS_16c	:= -DNUM_CLUSTERS=1 -DNUM_CORES=16 -DL2_ENABLE
    CONFIGS_32c := -DNUM_CLUSTERS=2 -DNUM_CORES=16 -DL2_ENABLE
    CONFIGS_64c := -DNUM_CLUSTERS=4 -DNUM_CORES=16 -DL2_ENABLE
    CONFIGS += $(CONFIGS_$(NUM_CORES)c)
    CONFIGS += -DNUM_WARPS=$(NUM_WARPS) -DNUM_THREADS=$(NUM_THREADS) -DNUM_BARRIERS=$(NUM_BARRIERS)
    CONFIGS += -DSTARTUP_ADDR=$(STARTUP_ADDR) -DSTACK_BASE_ADDR=$(STACK_BASE_ADDR)
    CONFIGS += -DMEM_BLOCK_SIZE=$(MEM_BLOCK_SIZE)

ifeq ($(EXT_F_EN), 0)
    CONFIGS += -DEXT_F_DISABLE=1
endif
ifeq ($(EXT_M_EN), 0)
    CONFIGS += -DEXT_M_DISABLE=1
endif

ifeq ($(DBG_TRACE_EN), 1)
    CONFIGS += $(DBG_TRACE_FLAGS)
endif

CXXFLAGS += $(CONFIGS)

# Dump perf stats
#CXXFLAGS += -DDUMP_PERF_STATS

#LDFLAGS += -shared -ldl

# Debugigng
ifdef DEBUG
	CXXFLAGS += -g -O0
else    
	CXXFLAGS += -O2 -DNDEBUG
endif

# Enable scope logic analyzer
ifdef SCOPE
	CXXFLAGS += -DSCOPE	
	SRCS += ../common/scope.cpp
endif

# Enable perf counters
ifdef PERF
	CXXFLAGS += -DPERF_ENABLE
endif

PROJECT = libvortex.a

all: $(DESTDIR)/$(PROJECT)


%/:
	mkdir -p $@

%.h: $(SYN_DIR)/%.vh
	$(HW_DIR)/scripts/gen_config.py -i $< -o $@

$(BUILDIR)/vortex.o: $(BUILDIR)/ $(H_FILES) vortex.cpp
	$(CXX) $(CXXFLAGS) vortex.cpp -c -o $@
$(BUILDIR)/axictrl.o: $(BUILDIR)/ $(H_FILES) axictrl.cpp
	$(CXX) $(CXXFLAGS) axictrl.cpp -c -o $@
$(BUILDIR)/utils.o: $(BUILDIR)/ $(H_FILES) ../common/utils.cpp
	$(CXX) $(CXXFLAGS) ../common/utils.cpp -c -o $@

$(DESTDIR)/$(PROJECT): $(DESTDIR)/ $(BUILDIR)/vortex.o $(BUILDIR)/axictrl.o $(BUILDIR)/utils.o 
	$(AR) rcs $(DESTDIR)/$(PROJECT) $(BUILDIR)/*.o

clean:
	rm -rf $(BUILDIR)/ $(H_FILES)

clean-all: clean
	rm -rf $(DESTDIR)/$(PROJECT)
