### GRLIB general setup and extra target to clean software

include .config
GRLIB=../..
CLEAN=soft-clean

############  Leon Core  ########################

GRLIB_CONFIG=grlib_config.vhd

############  Board Setup  ########################

### Xilinx Vivado device and board setup
BOARD=xilinx-zcu102-xczu9eg
DESIGN=leon3-xilinx-zcu102
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

############  Project  ########################

### Simulation Options ###
# Design Top Level
TOP=leon3mp
DIRADD += sparrow/proc/leon3

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR=Vivado

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT= -L work -L secureip -L unisims_ver glbl
GRLIB_COMPILE_VIVADO_IP=Y

# GRETH options
#ifeq ($(CONFIG_GRETH_ENABLE),y)
#VSIMOPT+= -L gig_ethernet_pcs_pma_v16_1_3
#endif

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc -nowarn 1" +notimingchecks
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

VIVADO_IMPL_STRATEGY=Congestion_SpreadLogic_low

### End of Synthesize Options ###

### Testbench, design and libraries to compile and not to compile

RTL=$(GRLIB)/designs/$(DESIGN)/rtl

VHDLSYNFILES= rtl/ddr4ram.vhd config.vhd ahbrom.vhd leon3mp.vhd $(MEMTECH) \
rtl/ahb2axi_mig4_ultrascale.vhd 
#rtl/axi_mig4_7series.vhd 
VHDLSIMFILES= testbench.vhd 

VERILOGSYNFILES=

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig atf micron \
	esa fmf
LIBADD = testgrouppolito
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft srio idt crypto satcan pci ambatest \
	ascs slink  \
	pwm gr1553b iommu ac97 secureip canfd \
	nand grrm mma lram riscv noelv noelv/subsys
ifeq ("$(CONFIG_LEON4)","")
DIRSKIP+=leon4v0
endif
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile
