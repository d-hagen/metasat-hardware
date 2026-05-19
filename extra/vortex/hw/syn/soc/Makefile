ifneq ($(findstring Makefile, $(MAKEFILE_LIST)), Makefile)
    help:
    $(ECHO) "Makefile Usage:"
    $(ECHO) "  make all"
    $(ECHO) "      Command to generate the design."
    $(ECHO) ""
    $(ECHO) "  make grlib"
    $(ECHO) "      Command to generate the design for using with GRLIB cores."
    $(ECHO) ""
    $(ECHO) "  make clean"
    $(ECHO) "      Command to remove the generated non-hardware files."
    $(ECHO) ""
endif

RTL_DIR = ../../rtl
AFU_DIR = $(RTL_DIR)/afu/soc/axi
SCRIPT_DIR = ../../scripts
THIRD_PARTY_DIR = ../../../third_party

RMDIR = rm -rf
ECHO = @echo

BUILD_DIR = src

SVLOGSYN = grlib/svlogsyn.txt

ifneq ("$(wildcard $(VX_CONFIG))","")
    include $(VX_CONFIG)
else
    # Design configuration
    XLEN ?= 32
    NUM_CORES ?= 1
    NUM_WARPS ?= 4
    NUM_THREADS ?= 4
    NUM_BARRIERS ?= 4
    STARTUP_ADDR ?= 1610612736
    STACK_BASE_ADDR ?= 2130706432
    MEM_BLOCK_SIZE ?= 16
    EXT_F_EN ?= 0
    EXT_M_EN ?= 1

endif
    # Control RTL debug tracing states
    DBG_TRACE_FLAGS += -DDBG_TRACE_CORE_PIPELINE  
    DBG_TRACE_FLAGS += -DDBG_TRACE_CORE_ICACHE
    DBG_TRACE_FLAGS += -DDBG_TRACE_CORE_DCACHE
    DBG_TRACE_FLAGS += -DDBG_TRACE_CORE_MEM
    DBG_TRACE_FLAGS += -DDBG_TRACE_CACHE_BANK 
    DBG_TRACE_FLAGS += -DDBG_TRACE_CACHE_MSHR
    DBG_TRACE_FLAGS += -DDBG_TRACE_CACHE_TAG
    DBG_TRACE_FLAGS += -DDBG_TRACE_CACHE_DATA
    DBG_TRACE_FLAGS += -DDBG_TRACE_AFU
    DBG_TRACE_FLAGS += -DDBG_TRACE_GBAR

    # Control logic analyzer monitors
    DBG_SCOPE_FLAGS += -DDBG_SCOPE_AFU
    DBG_SCOPE_FLAGS += -DDBG_SCOPE_ISSUE
    DBG_SCOPE_FLAGS += -DDBG_SCOPE_FETCH
    DBG_SCOPE_FLAGS += -DDBG_SCOPE_LSU
    DBG_SCOPE_FLAGS += -DDBG_SCOPE_MSCHED
    
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
    
    # compilation flags
    CFLAGS += -DSYNTHESIS -DVIVADO
    CFLAGS += -DXLEN_$(XLEN)
    CFLAGS += $(CONFIGS)
    CFLAGS += $(RTL_INCLUDE)

# include paths
FPU_INCLUDE = -I$(RTL_DIR)/fpu
ifneq (,$(findstring FPU_FPNEW,$(CONFIGS)))
    FPU_INCLUDE += -I$(THIRD_PARTY_DIR)/fpnew/src/common_cells/include -I$(THIRD_PARTY_DIR)/fpnew/src/common_cells/src -I$(THIRD_PARTY_DIR)/fpnew/src/fpu_div_sqrt_mvp/hdl -I$(THIRD_PARTY_DIR)/fpnew/src
endif
RTL_INCLUDE = -I$(RTL_DIR) -I$(RTL_DIR)/libs -I$(RTL_DIR)/interfaces -I$(RTL_DIR)/core -I$(RTL_DIR)/mem -I$(RTL_DIR)/cache -I$(AFU_DIR)
RTL_INCLUDE += $(FPU_INCLUDE)

# Debugigng
ifdef DEBUG
    CFLAGS += -DNDEBUG -DSCOPE $(DBG_SCOPE_FLAGS)
else
    CFLAGS += -DNDEBUG
endif
    

.PHONY: all clean gen-sources

all: sources.txt

sources.txt: $(VX_CONFIG)
	mkdir -p $(BUILD_DIR); $(SCRIPT_DIR)/gen_sources.sh -P $(CFLAGS) -C$(BUILD_DIR) -Osources.txt
	@rm -rf obj_dir

grlib: sources.txt
	@echo "Generating svlogsyn.txt file"
	@sed '/^+/d' $< > $(SVLOGSYN)
	@sed -i 's|$(CURDIR)|..|' $(SVLOGSYN)
	
clean:
	$(RMDIR) $(BUILD_DIR) $(SVLOGSYN) sources.txt obj_dir
