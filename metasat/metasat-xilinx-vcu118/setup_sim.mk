# QuestaSim Simulation Setup Makefile
#
# Usage:
#   make -f setup_sim.mk UNISIM_SRC=~/unisims SIM_DIR=$(pwd) all
#
# Or run individual targets:
#   make -f setup_sim.mk UNISIM_SRC=~/unisims compile-unisim
#   make -f setup_sim.mk SIM_DIR=$(pwd) map-unisim
#   make -f setup_sim.mk SIM_DIR=$(pwd) TEST=memory select-test
#   make -f setup_sim.mk SIM_DIR=$(pwd) run-sim

# ---- Environment setup ----
export PATH := /opt/siemens/questasim/bin:$(PATH)
export SALT_LICENSE_SERVER := 1717@questa.fib.upc.edu

# ---- User-configurable paths ----
UNISIM_SRC   ?= ../../../unisims
SIM_DIR      ?= $(CURDIR)
GRLIB        ?= ../../grlib
QUESTASIM    ?= /opt/siemens/questasim/bin
EVAL_DIR     ?= ../../extra/vortex/eval
TEST         ?= memory

# ---- Derived paths ----
UNISIM_LIB   = $(UNISIM_SRC)/unisim

.PHONY: all check-paths compile-unisim map-unisim scripts-gen \
        patch-aximem select-test run-sim clean-unisim help

all: check-paths compile-unisim scripts-gen map-unisim select-test
	@echo ""
	@echo "=== Setup complete ==="
	@echo "Run:  make metasat-sim"
	@echo "Or:   make vsim-launch"

# ---- Step 1: Verify prerequisites ----
check-paths:
	@echo "=== Checking prerequisites ==="
	@which vlib  > /dev/null 2>&1 || (echo "ERROR: QuestaSim not on PATH" && exit 1)
	@which vcom  > /dev/null 2>&1 || (echo "ERROR: QuestaSim not on PATH" && exit 1)
	@test -d "$(UNISIM_SRC)" || (echo "ERROR: UNISIM_SRC=$(UNISIM_SRC) not found" && exit 1)
	@test -f "$(UNISIM_SRC)/unisim_VCOMP.vhd" || (echo "ERROR: unisim_VCOMP.vhd not found in $(UNISIM_SRC)" && exit 1)
	@echo "OK"

# ---- Step 2: Compile UNISIM library (order matters) ----
compile-unisim: check-paths
	@echo "=== Compiling UNISIM library ==="
	cd $(UNISIM_SRC) && vlib unisim
	cd $(UNISIM_SRC) && vcom -work unisim unisim_VCOMP.vhd
	cd $(UNISIM_SRC) && vcom -work unisim unisim_VPKG.vhd
	cd $(UNISIM_SRC) && vcom -work unisim unisim_retarget_VCOMP.vhd
	cd $(UNISIM_SRC) && vcom -work unisim primitive/*.vhd
	cd $(UNISIM_SRC) && vcom -work unisim retarget/*.vhd
	@echo "=== UNISIM compiled ==="

# ---- Step 3: Map UNISIM into simulation directory ----
map-unisim:
	@echo "=== Mapping UNISIM library ==="
	cd $(SIM_DIR) && vmap unisim $(abspath $(UNISIM_LIB))
	@grep -q 'vmap unisim' $(SIM_DIR)/libs.do 2>/dev/null || \
		echo 'vmap unisim $(abspath $(UNISIM_LIB))' >> $(SIM_DIR)/libs.do
	@echo "=== UNISIM mapped ==="

# ---- Step 4: Generate GRLIB scripts ----
scripts-gen:
	@echo "=== Generating GRLIB scripts ==="
	cd $(SIM_DIR) && $(MAKE) scripts

# ---- Step 5: Patch aximem.vhd AXI ID width (4 -> 32) ----
patch-aximem:
	@echo "=== Patching aximem.vhd ID width to 32 ==="
	sed -i 's/id: std_logic_vector(3 downto 0)/id: std_logic_vector(31 downto 0)/g' \
		$(GRLIB)/lib/gaisler/sim/aximem.vhd
	@echo "=== Patched ==="

# ---- Step 6: Select test program ----
select-test:
ifeq ($(TEST),memory)
	@echo "=== Selecting memory test ==="
	cp $(EVAL_DIR)/memory/gpu-memory.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),evaluation)
	@echo "=== Selecting evaluation test ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation.srec $(SIM_DIR)/ram.srec
else
	@echo "ERROR: Unknown TEST=$(TEST). Use TEST=memory or TEST=evaluation"
	@exit 1
endif

# ---- Step 7: Run simulation ----
run-sim: patch-aximem
	@echo "=== Running simulation ==="
	cd $(SIM_DIR) && $(MAKE) metasat-sim

# ---- Utilities ----
clean-unisim:
	rm -rf $(UNISIM_LIB)

help:
	@echo "QuestaSim Simulation Setup"
	@echo ""
	@echo "Targets:"
	@echo "  all             - Full setup (compile UNISIM, map, generate scripts, select test)"
	@echo "  compile-unisim  - Compile Xilinx UNISIM VHDL library"
	@echo "  map-unisim      - Map UNISIM library into simulation directory"
	@echo "  scripts-gen     - Generate GRLIB simulation scripts"
	@echo "  patch-aximem    - Fix AXI ID width in aximem.vhd (4 -> 32 bits)"
	@echo "  select-test     - Copy test .srec to ram.srec (TEST=memory|evaluation)"
	@echo "  run-sim         - Patch + run full simulation (make metasat-sim)"
	@echo "  clean-unisim    - Delete compiled UNISIM library"
	@echo ""
	@echo "Variables:"
	@echo "  UNISIM_SRC      - Path to unisims/ source folder  (default: ~/unisims)"
	@echo "  SIM_DIR         - Simulation working directory     (default: current dir)"
	@echo "  TEST            - Test to run: memory|evaluation   (default: memory)"
	@echo "  QUESTASIM       - QuestaSim bin path               (default: /opt/siemens/questasim/bin)"
