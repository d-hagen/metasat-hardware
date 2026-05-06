# QuestaSim Simulation Setup Makefile
#
# After cloning/pulling the repo on the uni laptop:
#   cd metasat/metasat-xilinx-vcu118
#   make -f setup_sim.mk all       # one-time setup (compiles UNISIM, generates scripts, patches)
#   make -f setup_sim.mk run-sim   # run memory test
#   make -f setup_sim.mk TEST=evaluation run-sim  # run evaluation test

# ---- Environment setup ----
export PATH := /opt/siemens/questasim/bin:$(PATH)
export SALT_LICENSE_SERVER := 1717@questa.fib.upc.edu

# ---- User-configurable paths ----
UNISIM_SRC   ?= ../../../unisims
SIM_DIR      ?= $(CURDIR)
GRLIB        ?= ../../grlib
EVAL_DIR     ?= ../../extra/vortex/eval
TEST         ?= memory

# ---- Derived paths ----
UNISIM_LIB   = $(UNISIM_SRC)/unisim
AXI_SIM_DIR  = $(GRLIB)/lib/gaisler/sim

.PHONY: all check-paths compile-unisim scripts-gen map-unisim \
        stub-libs patch-aximem select-test compile-rtl run-sim \
        clean-unisim help

all: check-paths compile-unisim scripts-gen map-unisim stub-libs patch-aximem select-test compile-rtl
	@echo ""
	@echo "=== Setup complete ==="
	@echo "Run:  make -f setup_sim.mk run-sim"
	@echo "      make -f setup_sim.mk TEST=evaluation run-sim"

# ---- Step 1: Verify prerequisites ----
check-paths:
	@echo "=== Checking prerequisites ==="
	@which vlib  > /dev/null 2>&1 || (echo "ERROR: QuestaSim not on PATH" && exit 1)
	@which vcom  > /dev/null 2>&1 || (echo "ERROR: QuestaSim not on PATH" && exit 1)
	@test -d "$(UNISIM_SRC)" || (echo "ERROR: UNISIM_SRC=$(UNISIM_SRC) not found. Place unisims/ next to metasat-hardware/" && exit 1)
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

# ---- Step 3: Regenerate GRLIB scripts (discovers vortex library via dirs.txt) ----
scripts-gen:
	@echo "=== Generating GRLIB scripts ==="
	cd $(SIM_DIR) && $(MAKE) scripts-clean
	cd $(SIM_DIR) && $(MAKE) scripts

# ---- Step 4: Map UNISIM into simulation directory ----
map-unisim:
	@echo "=== Mapping UNISIM library ==="
	cd $(SIM_DIR) && vmap unisim $(abspath $(UNISIM_LIB))
	@grep -q 'vmap unisim' $(SIM_DIR)/libs.do 2>/dev/null || \
		echo 'vmap unisim $(abspath $(UNISIM_LIB))' >> $(SIM_DIR)/libs.do
	@echo "=== UNISIM mapped ==="

# ---- Step 5: Create placeholder Xilinx sim libraries ----
# The Makefile passes -L secureip -L unisims_ver to vsim.
# With CONFIG_MIG_7SERIES_MODEL=y these are not needed, but vsim
# fails if the libraries don't exist at all. Empty stubs fix this.
stub-libs:
	@echo "=== Creating placeholder Xilinx sim libraries ==="
	-cd $(SIM_DIR) && vlib secureip 2>/dev/null
	-cd $(SIM_DIR) && vlib unisims_ver 2>/dev/null
	@echo "=== Stub libraries created ==="

# ---- Step 6: Patch AXI sim models ID width (4 -> 32) ----
patch-aximem:
	@echo "=== Patching AXI sim model ID widths to 32 ==="
	for f in $(AXI_SIM_DIR)/aximem.vhd $(AXI_SIM_DIR)/axirep.vhd $(AXI_SIM_DIR)/axixmem.vhd; do \
		sed -i 's/id: std_logic_vector(3 downto 0)/id: std_logic_vector(31 downto 0)/g' $$f; \
		sed -i "s/id => \"0000\"/id => (others => '0')/g" $$f; \
	done
	@echo "=== Patched ==="

# ---- Step 7: Select test program ----
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

# ---- Step 8: Compile all RTL (GRLIB + NOEL-V + Vortex) ----
compile-rtl:
	@echo "=== Compiling RTL ==="
	cd $(SIM_DIR) && $(MAKE) metasat-sim

# ---- Step 9: Run simulation ----
run-sim: select-test
	@echo "=== Launching simulation ==="
	cd $(SIM_DIR) && $(MAKE) sim-run

# ---- Utilities ----
clean-unisim:
	rm -rf $(UNISIM_LIB)

help:
	@echo "QuestaSim Simulation Setup"
	@echo ""
	@echo "After cloning/pulling on the uni laptop:"
	@echo "  1. Place unisims/ folder next to metasat-hardware/"
	@echo "  2. cd metasat/metasat-xilinx-vcu118"
	@echo "  3. make -f setup_sim.mk all        (one-time, ~10 min)"
	@echo "  4. make -f setup_sim.mk run-sim     (launches simulation)"
	@echo ""
	@echo "Targets:"
	@echo "  all             - Full setup: UNISIM, scripts, patches, compile"
	@echo "  run-sim         - Launch simulation (memory test by default)"
	@echo "  select-test     - Copy test .srec to ram.srec"
	@echo "  compile-rtl     - Recompile RTL only (after code changes)"
	@echo "  clean-unisim    - Delete compiled UNISIM library"
	@echo ""
	@echo "Variables:"
	@echo "  UNISIM_SRC      - Path to unisims/ folder  (default: ../../../unisims)"
	@echo "  TEST            - memory | evaluation       (default: memory)"
