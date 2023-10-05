### GRLIB general setup and extra target to clean software

############  RISC-V NOEL-V Core  ########################

BASE_DIR ?= .
GRLIB 		= $(BASE_DIR)/../..
CFG_DIR  ?= $(BASE_DIR)
TB_DIR 	 ?= $(BASE_DIR)/tb
RTL_DIR  ?= $(BASE_DIR)/rtl
SYS_DIR  ?= $(RTL_DIR)/sys
CFG_LOCAL_DIR ?= $(CFG_DIR)/cfg
GRLIB_CONFIG 	?= $(CFG_DIR)/grlib_config.vhd
include $(CFG_DIR)/.config

### RISC-V NOEL-V Core  ##################################

#32-bit NOEL-V
XLEN ?= 32

DIRADD = noelv/pkg_$(XLEN)
DIRADD += noelv noelv/core noelv/subsys sparrow/proc/noelv

############  Board Setup  ########################

### Xilinx Vivado device and board setup
BOARD=xilinx-zcu102-xczu9eg
DESIGN=noelv-xilinx-zcu102
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

############  Project  ########################

### Simulation Options ###
# Design Top Level
TOP=noelvmp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR=Vivado

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT= -gdisas=0 -L secureip -L unisims_ver

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L gig_ethernet_pcs_pma_v16_1_1
endif

# MIG (TODO)
ifeq ($(CONFIG_MIG_7SERIES),y)
VSIMOPT+= -t 1ps -novopt
ifndef CONFIG_MIG_7SERIES_MODEL
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false
else
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps
endif
endif

VIVADO_IMPL_STRATEGY = Performance_ExplorePostRoutePhysOpt

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+=-novopt +notimingchecks
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

### End of Synthesize Options ###

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES  = 
VHDLSYNFILES += $(CFG_DIR)/config.vhd
#VHDLSYNFILES += $(CFG_LOCAL_DIR)/config_local.vhd
VHDLSYNFILES += $(SYS_DIR)/sys.vhd
VHDLSYNFILES += $(SYS_DIR)/clkrst.vhd
VHDLSYNFILES += $(RTL_DIR)/noelvmp.vhd 
VHDLSIMFILES  = $(TB_DIR)/testbench.vhd 

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig fmf esa micron spfi 
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft leon5 leon5v0 srio idt crypto satcan pci ambatest \
	spacewire ascs slink irqmp grdmac grrm nand\
	pwm gr1553b iommu ac97 secureip mmuiface clk2x canfd leon4v0 spacefibre
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd iu4.vhd sparc/cpu_disas.vhd

### Regenerate AHBROM #################################################

ahbrom_gen: prom.exe
	make ahbrom.vhd
	make ahbrom64.vhd
	make ahbrom128.vhd
	mv ahbrom.vhd ahbrom64.vhd ahbrom128.vhd rtl/

prom.exe: prom.elf
	cp prom.elf prom.exe

### Makefile Includes #################################################

include $(GRLIB)/software/noelv/systest/Makefile
OBJCOPY_CMD = $(OBJCOPY)

include $(GRLIB)/bin/Makefile

##################  project specific targets ##########################

### Simulation ###
#### Synthesis ###
