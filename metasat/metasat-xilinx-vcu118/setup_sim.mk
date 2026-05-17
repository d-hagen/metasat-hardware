# QuestaSim Simulation Setup Makefile
#
# After cloning/pulling the repo on the uni laptop:
#   cd metasat/metasat-xilinx-vcu118
#   make -f setup_sim.mk all       # one-time setup (compiles UNISIM, generates scripts, patches)
#   make -f setup_sim.mk run-sim   # run memory test
#   make -f setup_sim.mk TEST=evaluation run-sim       # run evaluation test
#   make -f setup_sim.mk TEST=memory-light run-sim     # run fast memory test (SIZE=16)
#   make -f setup_sim.mk TEST=evaluation-light run-sim # run fast evaluation test (SIZE=16)

# ---- Environment setup ----
export PATH := /opt/siemens/questasim/bin:$(PATH)
export SALT_LICENSE_SERVER := 1717@questa.fib.upc.edu

# ---- User-configurable paths ----
UNISIM_SRC   ?= /dades/dan.joshua.hagen/unisims
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
	@test -d "$(UNISIM_SRC)" || (echo "ERROR: UNISIM_SRC=$(UNISIM_SRC) not found. Place unisims/ in /dades/dan.joshua.hagen/" && exit 1)
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
	@echo "=== Selecting memory test (SIZE=1024) ==="
	cp $(EVAL_DIR)/memory/gpu-memory.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),memory-light)
	@echo "=== Selecting memory-light test (SIZE=16) ==="
	cp $(EVAL_DIR)/memory/gpu-memory-light.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),evaluation)
	@echo "=== Selecting evaluation test (SIZE=1024) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),evaluation-light)
	@echo "=== Selecting evaluation-light test (SIZE=16) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-light.srec $(SIM_DIR)/ram.srec
else
	@echo "ERROR: Unknown TEST=$(TEST). Use TEST=memory|memory-light|evaluation|evaluation-light"
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
	@echo "  UNISIM_SRC      - Path to unisims/ folder  (default: /dades/dan.joshua.hagen/unisims)"
	@echo "  TEST            - memory | memory-light | evaluation | evaluation-light  (default: memory)"
	@echo ""
	@echo "Reconfiguring after vx_config.inc changes:"
	@echo "  make -f setup_sim.mk reconfig                    (uses current vx_config.inc)"
	@echo "  make -f setup_sim.mk reconfig CORES=1            (set NUM_CORES=1 then rebuild)"
	@echo "  make -f setup_sim.mk reconfig CORES=2 WARPS=4 THREADS=4"
	@echo "  make -f setup_sim.mk reconfig NCPU=1 L2_EN=0 CPU_CFG=513   (CPU config in config.vhd)"
	@echo "  make -f setup_sim.mk reconfig CORES=1 NCPU=1 L2_EN=0 CPU_CFG=513   (combined)"
	@echo "  make -f setup_sim.mk check-config                (read-only diagnostic, no rebuild)"
	@echo "  make -f setup_sim.mk reconfig-full CORES=1 NCPU=1 (true ground-up rebuild incl. UNISIM, ~15+ min)"

# ============================================================
# Reconfigure: clean rebuild after editing vx_config.inc
# ============================================================
# Usage:
#   1. edit vx_config.inc (e.g. NUM_CORES = 1)
#   2. make -f setup_sim.mk reconfig
#   3. make -f setup_sim.mk TEST=memory-light run-sim
#
# This nukes all cached Vortex/QuestaSim state and verifies that
# NUM_CORES from vx_config.inc actually propagates through the
# build pipeline (sources.txt -> work library).

VX_SOC_DIR = ../../extra/vortex/hw/syn/soc

.PHONY: reconfig check-config

reconfig:
	@if [ -n "$(CORES)" ]; then \
		echo "=== Setting NUM_CORES = $(CORES) in vx_config.inc ==="; \
		sed -i "s|^\([[:space:]]*NUM_CORES[[:space:]]*=[[:space:]]*\).*|\\1$(CORES)|" vx_config.inc; \
	fi; \
	if [ -n "$(WARPS)" ]; then \
		echo "=== Setting NUM_WARPS = $(WARPS) in vx_config.inc ==="; \
		sed -i "s|^\([[:space:]]*NUM_WARPS[[:space:]]*=[[:space:]]*\).*|\\1$(WARPS)|" vx_config.inc; \
	fi; \
	if [ -n "$(THREADS)" ]; then \
		echo "=== Setting NUM_THREADS = $(THREADS) in vx_config.inc ==="; \
		sed -i "s|^\([[:space:]]*NUM_THREADS[[:space:]]*=[[:space:]]*\).*|\\1$(THREADS)|" vx_config.inc; \
	fi; \
	if [ -n "$(XLEN)" ]; then \
		echo "=== Setting XLEN = $(XLEN) in vx_config.inc ==="; \
		sed -i "s|^\([[:space:]]*XLEN[[:space:]]*=[[:space:]]*\).*|\\1$(XLEN)|" vx_config.inc; \
	fi; \
	if [ -n "$(NCPU)" ]; then \
		echo "=== Setting CFG_NCPU = $(NCPU) in config.vhd ==="; \
		sed -i "s|^\([[:space:]]*constant CFG_NCPU[[:space:]]*:[[:space:]]*integer[[:space:]]*:=[[:space:]]*\)([0-9]\+);|\\1($(NCPU));|" config.vhd; \
	fi; \
	if [ -n "$(L2_EN)" ]; then \
		echo "=== Setting CFG_L2_EN = $(L2_EN) in config.vhd ==="; \
		sed -i "s|^\([[:space:]]*constant CFG_L2_EN[[:space:]]*:[[:space:]]*integer[[:space:]]*:=[[:space:]]*\)[0-9]\+;|\\1$(L2_EN);|" config.vhd; \
	fi; \
	if [ -n "$(CPU_CFG)" ]; then \
		echo "=== Setting CFG_CFG = $(CPU_CFG) in config.vhd ==="; \
		sed -i "s|^\([[:space:]]*constant CFG_CFG[[:space:]]*:[[:space:]]*integer[[:space:]]*:=[[:space:]]*\).*;|\\1$(CPU_CFG);|" config.vhd; \
	fi; \
	EXPECTED_CORES=$$(grep -E "^[[:space:]]*NUM_CORES[[:space:]]*=" vx_config.inc | sed "s/.*=[[:space:]]*//" | tr -d " "); \
	echo "=== Expected NUM_CORES from vx_config.inc: $$EXPECTED_CORES ==="; \
	if [ -z "$$EXPECTED_CORES" ]; then echo "FAIL: NUM_CORES not found in vx_config.inc"; exit 1; fi; \
	echo ""; \
	echo "=== Wiping cached state ==="; \
	rm -rf .vortex work libs make.work make.vsim make.bem; \
	$(MAKE) -C $(VX_SOC_DIR) clean 2>/dev/null || true; \
	echo ""; \
	echo "=== Regenerating Vortex sources ==="; \
	$(MAKE) -C $(VX_SOC_DIR) grlib VX_CONFIG=$(abspath vx_config.inc); \
	echo ""; \
	echo "=== Verifying sources.txt has NUM_CORES=$$EXPECTED_CORES ==="; \
	grep "NUM_CORES\|NUM_CLUSTERS" $(VX_SOC_DIR)/sources.txt; \
	if ! grep -q "+define+NUM_CORES=$$EXPECTED_CORES" $(VX_SOC_DIR)/sources.txt; then \
		echo "FAIL: sources.txt does not have +define+NUM_CORES=$$EXPECTED_CORES"; \
		exit 1; \
	fi; \
	echo "OK: sources.txt correct"; \
	echo ""; \
	echo "=== Regenerating GRLIB scripts ==="; \
	$(MAKE) scripts-clean; \
	$(MAKE) scripts; \
	echo ""; \
	echo "=== Re-mapping libraries and patching sim models ==="; \
	$(MAKE) -f setup_sim.mk map-unisim stub-libs patch-aximem; \
	echo ""; \
	echo "=== Recompiling RTL ==="; \
	$(MAKE) metasat-sim; \
	echo ""; \
	echo ""; \
	echo "=== Reconfiguration complete ==="; \
	echo "Run: make -f setup_sim.mk TEST=memory-light run-sim"

# ---- Full ground-up rebuild including UNISIM (slow, ~15+ min) ----
# Use when you suspect anything cached is wrong. Accepts the same flags as reconfig.
.PHONY: reconfig-full

reconfig-full:
	@echo "=== FULL REBUILD: wiping UNISIM library ==="
	rm -rf $(UNISIM_LIB)
	@echo "=== Recompiling UNISIM from source (this takes ~10 min) ==="
	$(MAKE) -f setup_sim.mk compile-unisim
	@echo "=== Running reconfig with same flags ==="
	$(MAKE) -f setup_sim.mk reconfig CORES="$(CORES)" WARPS="$(WARPS)" THREADS="$(THREADS)" XLEN="$(XLEN)" NCPU="$(NCPU)" L2_EN="$(L2_EN)" CPU_CFG="$(CPU_CFG)"

# ---- Check current build state without rebuilding ----
check-config:
	@echo "=== vx_config.inc ==="
	@grep -E "^[[:space:]]*(NUM_CORES|NUM_WARPS|NUM_THREADS|XLEN)[[:space:]]*=" vx_config.inc
	@echo ""
	@echo "=== sources.txt defines ==="
	@if [ -f $(VX_SOC_DIR)/sources.txt ]; then \
		grep "NUM_CORES\|NUM_CLUSTERS\|XLEN\|NUM_WARPS\|NUM_THREADS" $(VX_SOC_DIR)/sources.txt; \
	else \
		echo "  (sources.txt not generated - run reconfig)"; \
	fi
	@echo ""
	@echo "=== Work library state ==="
	@if [ -d work ]; then \
		echo "  vx_config.inc modified: $$(stat -c %y vx_config.inc)"; \
		newest=$$(find work -name "_info" -printf "%TY-%Tm-%Td %TH:%TM  %p\n" 2>/dev/null | sort | tail -1); \
		echo "  newest work/_info:      $$newest"; \
		stale=$$(find work -name "_info" -not -newer vx_config.inc 2>/dev/null | wc -l); \
		fresh=$$(find work -name "_info" -newer vx_config.inc 2>/dev/null | wc -l); \
		echo "  fresh _info count: $$fresh    stale _info count: $$stale"; \
	else \
		echo "  (work/ does not exist - run reconfig)"; \
	fi
	@echo ""
	@echo "=== Preprocessed dev_caps in src/VX_afu_ctrl.sv (NUM_CORES*NUM_CLUSTERS, NUM_WARPS, NUM_THREADS baked in) ==="
	@if [ -f $(VX_SOC_DIR)/src/VX_afu_ctrl.sv ]; then \
		grep -A6 "wire \[63:0\] dev_caps" $(VX_SOC_DIR)/src/VX_afu_ctrl.sv | head -8; \
	else \
		echo "  (src/VX_afu_ctrl.sv not generated - run reconfig)"; \
	fi
