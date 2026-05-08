export PATH := /opt/siemens/questasim/bin:$(PATH)
export SALT_LICENSE_SERVER := 1717@questa.fib.upc.edu

### GRLIB general setup and extra target to clean software

############  RISC-V NOEL-V Core  ########################

LOCAL_DIR ?= .
GRLIB	  = ../../grlib
CORE_DIR ?= $(LOCAL_DIR)/rtl/core
CFG_DIR  ?= $(LOCAL_DIR)

CFG_LOCAL_DIR ?= $(CFG_DIR)/cfg
GRLIB_CONFIG  ?= $(CFG_DIR)/grlib_config.vhd
XDCPATH  ?=  $(GRLIB)
include $(CFG_DIR)/.config

CLEAN=vortex-clean #unpatch_vortex_synth

### RISC-V NOEL-V Core  ##################################

DIRADD = noelv/pkg_64 noelv noelv/core noelv/dm noelv/subsys noelv/grfpunv
DIRADD += sparrow/proc/noelv

############  Board Setup  ########################

### Xilinx Vivado device and board setup
BOARD=xilinx-vcu118-xcvu9p
DESIGN=metasat-xilinx-vcu118
include $(XDCPATH)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)-$(SPEED)
XDC=$(LOCAL_DIR)/board/$(BOARD).xdc

# Definition of the following variables generates SGMII and MIG xilinx IP output source files
# Do not alter these
CONFIG_GRETH_ENABLE=y
CONFIG_MIG_7SERIES=y

#######  Simulation : user configuration  #########
# Comment out the following line to simulate MIG IP. Else, an AXI memory will be generated in simulation
# The default case is an AXI memory connected to the backend of L2C/ahb2axib bridge. 
#Note: Refer README file for simulation steps, if the following line is COMMENTED OUT.
CONFIG_MIG_7SERIES_MODEL=y

############  Project  ########################

### Simulation Options ###
# Design Top Level
export TOP=metasat

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR=Questa

# Options used during compilation
VCOMOPT=-explicit -O0
VLOGOPT=-mixedsvvh
VHDLOPT=-mixedsvvh

# GRLIB Options
VSIMOPT= -gdisas=0 -L secureip -L unisims_ver

# GRETH options
ifeq ($(SIM_SGMII),y)
VSIMOPT+= -L gig_ethernet_pcs_pma_v16_1_9 -L gig_ethernet_pcs_pma_v16_2_1 -L gig_ethernet_pcs_pma -L xpm -gEXAMPLE_SIMULATION=1 
GRLIB_COMPILE_VIVADO_IP=y
endif

ifeq ($(CONFIG_MIG_7SERIES),y)
VIVADO_MIG_AXI=1
AXI_128=1
VSIMOPT+= -t 1ps
ifdef CONFIG_MIG_7SERIES_MODEL
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true
else
VSIMOPT+=-L xpm -L microblaze_v11_0_2 -L mig_ip -L lib_cdc_v1_0_2 -L proc_sys_reset_v5_0_13 -L lmb_v10_v3_0_10 \
-L lmb_bram_if_cntlr_v4_0_17 -L blk_mem_gen_v8_4_4 -L iomodule_v3_1_5 -L axi_infrastructure_v1_1_0 -L fifo_generator_v13_2_5 \
-L axi_clock_converter_v2_1_19 -L mig_cdc_ip -L mem_model
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false -t ps
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false -t ps
endif
endif

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+= -voptargs="+acc -nowarn 1" +notimingchecks
endif

GRLIB_XILINX_SOURCE_MGMT_MODE=DisplayOnly

# Remove collision check in UNSIM library
VSIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"
ASIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"

# Simulation scripts
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do
ASIMDO = run -all

# Toplevel
VSIMOPT+= $(SIMTOP)

### End of Simulation Options ###

### Synthesize Options ###

#VIVADO_SYNTH_STRATEGY = Flow_RuntimeOptimized
VIVADO_IMPL_STRATEGY = Performance_SpreadSLLs#Area_ExploreSequential

### End of Synthesize Options ###

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES  = 
VHDLSYNFILES += $(CFG_DIR)/config.vhd
VHDLSYNFILES += $(LOCAL_DIR)/rtl/ahbrom.vhd
VHDLSYNFILES += $(LOCAL_DIR)/rtl/ahbrom64.vhd
VHDLSYNFILES += $(LOCAL_DIR)/rtl/ahbrom128.vhd
#VHDLSYNFILES += $(LOCAL_DIR)/rtl/ahb2axi_mig4_7series.vhd
VHDLSYNFILES += $(LOCAL_DIR)/rtl/axi_mig4_7series.vhd
VHDLSYNFILES += $(LOCAL_DIR)/rtl/ddr4ram.vhd
VHDLSYNFILES += $(LOCAL_DIR)/rtl/sgmii_vcu118.vhd
VHDLSYNFILES += $(CFG_LOCAL_DIR)/config_local.vhd
VHDLSYNFILES += $(CORE_DIR)/rev.vhd
VHDLSYNFILES += $(CORE_DIR)/cfgmap.vhd
VHDLSYNFILES += $(CORE_DIR)/metasatcore.vhd
VHDLSYNFILES += $(LOCAL_DIR)/rtl/metasat.vhd 

VHDLSIMFILES= tb/testbench.vhd 

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig fmf esa micron spfi

DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft srio idt crypto satcan pci \
	ascs slink irqmp grdmac grrm nand leon3v3 leon5 leon5v0 hcan can \
	pwm gr1553b ac97 secureip mmuiface clk2x i2c spi leon4v0 spacefibre ftaddr

FILESKIP =  grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd \
	    iu4.vhd axinullslv.vhd

EXTRALIBS=../../extra


### Makefile Includes #################################################

#include $(GRLIB)/software/noelv/systest/Makefile
#OBJCOPY_CMD = $(OBJCOPY)

include $(GRLIB)/bin/Makefile

##################  project specific targets ##########################
VX_DIR := $(EXTRALIBS)/vortex/hw/syn/soc
VX_SRC := $(VX_DIR)/sources.txt

VX_INCDIR = $(shell grep '^\+incdir\+' $(VX_SRC))
VX_DEFINES = $(shell grep '^\+define\+' $(VX_SRC))

VX_CONFIG_FILE = vx_config.inc
VX_CONFIG = $(abspath $(LOCAL_DIR)/$(VX_CONFIG_FILE))

ID_WIDTH = 32

.PHONY: vortex
vortex: .vortex
.vortex:
	make -C $(VX_DIR) grlib VX_CONFIG=$(VX_CONFIG)
	touch .vortex

#### Synthesis ###
.PHONY: metasat-synth metasat-vivado metasat-sim
metasat-synth: vortex
	make patch-id-width
	make vivado

metasat-vivado: vortex
	make patch-id-width
	make vivado-launch

### Simulation ###
metasat-sim: compile.vsim
	make patch-id-width
	make patch_vortex_sim
	make sim

### Clean ###
vortex-clean:
	rm -rf .vortex
	make -C $(VX_DIR) clean

## AXI ID PATCH
cp-mig-files: scripts
	@echo "!!!!! Overwriting board mig files with local files"
	cp $(LOCAL_DIR)/board/mig.xci vivado/mig.xci
	cp $(LOCAL_DIR)/board/mig_cdc.xci vivado/mig_cdc.xci
	cp $(LOCAL_DIR)/board/axi_pipe.xci vivado/axi_pipe.xci

patch-id-width: cp-mig-files
	@echo "Patching AXI_ID_WIDTH to $(ID_WIDTH)"
	sed -i 's/\(constant AXI_ID_WIDTH : integer := \)[0-9]\+/\1$(ID_WIDTH)/' $(GRLIB)/lib/grlib/amba/amba.vhd
	sed -i 's/\(axi_bm_id_width  => \)[0-9]\+/\1$(ID_WIDTH)/' $(GRLIB)/lib/gaisler/l2c_lite/l2c_lite_axi4.vhd


## VORTEX ##

VX_PATCH_OG  = +incdir+../../extra/vortex/hw/syn/soc/grlib
VX_PATCH_NEW = $(VX_INCDIR) $(VX_DEFINES)

patch_vortex_sim: vortex make.vsim
	- sed -i "s|$(VX_PATCH_OG)|$(VX_PATCH_NEW)|g" make.vsim
	- sed -i '/VX_.*_pkg\.sv/s/-mixedsvvh//g' make.vsim
