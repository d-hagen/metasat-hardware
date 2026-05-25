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

# ============================================================
# wipe: clear all cached build state after editing vx_config.inc / config.vhd
# Run this before scripts-gen / compile-rtl when config changes.
# ============================================================
.PHONY: wipe
wipe:
	@echo "=== Wiping cached state (work, .vortex, make.*) ==="
	rm -rf work libs make.work make.vsim make.bem .vortex
	$(MAKE) -C ../../extra/vortex/hw/syn/soc clean
	@echo "=== Wipe complete. Next: ==="
	@echo "  make -f setup_sim.mk scripts-gen map-unisim stub-libs patch-aximem select-test compile-rtl"
	@echo "  make -f setup_sim.mk TEST=evaluation-light run-sim"

# ============================================================
# check-config: report CPU + GPU config from source files AND
# from current build artifacts. Surface drift between what the
# files say and what was actually baked into the build.
# ============================================================
.PHONY: check-config
check-config:
	@echo
	@echo "===== CPU config (config.vhd) ====="
	@grep -E "^[[:space:]]*constant (CFG_NOELV|CFG_NCPU|CFG_CFG|CFG_L2_EN|CFG_L2_SIZE|CFG_L2_WAYS|CFG_VX_EN|CFG_FPNPEN)" config.vhd
	@echo "  (CFG_CFG = CPU_TYPE*256 + FPU*128 + DUAL*2 + LITE; CPU_TYPE: HP=4, GP=3, MC=2)"
	@echo
	@echo "===== GPU config (vx_config.inc) ====="
	@grep -E "^[[:space:]]*(XLEN|NUM_CORES|NUM_WARPS|NUM_THREADS|NUM_BARRIERS|EXT_F_EN|EXT_M_EN|DBG_TRACE_EN)[[:space:]]*=" vx_config.inc
	@echo
	@echo "===== Build state — Vortex preprocessed sources ====="
	@if [ -f ../../extra/vortex/hw/syn/soc/sources.txt ]; then \
		echo "  sources.txt defines:"; \
		grep -E "\+define\+(NUM_CORES|NUM_CLUSTERS|NUM_WARPS|NUM_THREADS|XLEN|EXT)" ../../extra/vortex/hw/syn/soc/sources.txt | sed "s/^/    /"; \
	else \
		echo "  sources.txt: not generated  (run: make -f setup_sim.mk scripts-gen)"; \
	fi
	@if [ -f ../../extra/vortex/hw/syn/soc/src/VX_afu_ctrl.sv ]; then \
		echo; \
		echo "  src/VX_afu_ctrl.sv dev_caps (NUM_CORES*NUM_CLUSTERS, NUM_WARPS, NUM_THREADS literally baked in):"; \
		grep -A6 "wire \[63:0\] dev_caps" ../../extra/vortex/hw/syn/soc/src/VX_afu_ctrl.sv | head -8 | sed "s/^/    /"; \
	fi
	@echo
	@echo "===== Build state — QuestaSim ====="
	@if [ -f make.vsim ]; then \
		echo "  make.vsim NUM_CORES/CLUSTERS defines:"; \
		grep -E "\+define\+(NUM_CORES|NUM_CLUSTERS)" make.vsim | head -3 | sed "s/^/    /" || echo "    (no NUM_CORES defines — patch_vortex_sim did not run)"; \
	else \
		echo "  make.vsim: not generated  (run: make -f setup_sim.mk scripts-gen)"; \
	fi
	@fresh=$$(find . -maxdepth 2 -name _info -newer vx_config.inc 2>/dev/null | wc -l); \
	stale=$$(find . -maxdepth 2 -name _info -not -newer vx_config.inc 2>/dev/null | wc -l); \
	if [ "$$fresh" -eq 0 ] && [ "$$stale" -eq 0 ]; then \
		echo "  compiled libraries: none built yet"; \
	else \
		echo "  compiled libraries: $$fresh _info files newer than vx_config.inc, $$stale older"; \
		if [ "$$stale" -gt 0 ] && [ "$$fresh" -eq 0 ]; then \
			echo "  >>> STALE: libraries predate current config -- run make -f setup_sim.mk wipe <<<"; \
		fi; \
	fi
	@if [ -f .vortex ]; then \
		echo "  .vortex marker: present (blocks Vortex source regen — wipe if vx_config.inc changed)"; \
	fi
	@echo

# ============================================================
# nuke: maximal wipe -- repo state + all compiled libraries +
# UNISIM library + stubs + run artifacts + Vortex src/.
# Use when you suspect environmental corruption (aborted
# compiles, partial files, stale UNISIM, etc.). Takes ~15 min
# to rebuild from scratch.
# ============================================================
.PHONY: nuke
nuke:
	@echo "=== NUCLEAR wipe: repo build state ==="
	rm -rf work libs make.work make.vsim make.bem .vortex
	@echo "=== Compiled libraries (vortex/, grlib/, gaisler/, ...) ==="
	rm -rf vortex grlib gaisler techmap noelv sparrow secureip unisims_ver
	@echo "=== ModelSim config + stub libs in cwd ==="
	rm -f modelsim.ini
	@echo "=== vsim run artifacts ==="
	rm -f transcript vsim.wlf vsim*.dbg vsim*.vstf vsim_stacktrace.vstf .vsim*
	@echo "=== Selected test image ==="
	rm -f ram.srec
	@echo "=== Vortex preprocessed src/ + sources.txt ==="
	$(MAKE) -C ../../extra/vortex/hw/syn/soc clean
	@echo "=== Compiled UNISIM library ($(UNISIM_SRC)/unisim) -- the big one ==="
	rm -rf $(UNISIM_SRC)/unisim
	@echo ""
	@echo "=== NUKE complete. Run next: ==="
	@echo "  make -f setup_sim.mk all                            # ~15 min: full rebuild incl. UNISIM"
	@echo "  make -f setup_sim.mk TEST=memory-light run-sim      # run smallest test"

# ============================================================
# check-all: check-config + library timestamps + UNISIM
# status + corruption probes (empty files in src/).
# Run anytime to verify the build is in a sane state.
# ============================================================
.PHONY: check-all
check-all: check-config
	@echo
	@echo "===== Compiled libraries (timestamps) ====="
	@found=0; \
	for info in $$(find . -maxdepth 2 -name _info 2>/dev/null | sort); do \
		found=1; \
		lib=$$(dirname $$info | sed "s|^\./||"); \
		ts=$$(stat -c "%y" $$info 2>/dev/null | cut -d. -f1); \
		if [ $$info -nt vx_config.inc ]; then status="fresh"; else status="STALE"; fi; \
		printf "  %-15s %s  [%s]\n" "$$lib" "$$ts" "$$status"; \
	done; \
	if [ "$$found" -eq 0 ]; then echo "  (no libraries built yet)"; fi
	@echo
	@echo "===== UNISIM compiled library ====="
	@if [ -d "$(UNISIM_SRC)/unisim" ]; then \
		sz=$$(du -sh $(UNISIM_SRC)/unisim 2>/dev/null | cut -f1); \
		echo "  $(UNISIM_SRC)/unisim: present ($$sz)"; \
	else \
		echo "  $(UNISIM_SRC)/unisim: MISSING -- run make -f setup_sim.mk compile-unisim"; \
	fi
	@echo
	@echo "===== Vortex preprocessed src/ (corruption probe) ====="
	@if [ -d ../../extra/vortex/hw/syn/soc/src ]; then \
		n=$$(ls ../../extra/vortex/hw/syn/soc/src/ 2>/dev/null | wc -l); \
		echo "  src/: $$n files"; \
		empty=$$(find ../../extra/vortex/hw/syn/soc/src/ -type f -size 0 2>/dev/null | wc -l); \
		if [ "$$empty" -gt 0 ]; then \
			echo "  >>> $$empty empty files in src/ -- preprocessing aborted mid-way <<<"; \
			find ../../extra/vortex/hw/syn/soc/src/ -type f -size 0 | sed "s/^/    /"; \
			echo "  Fix: make -f setup_sim.mk nuke (then make all)"; \
		else \
			echo "  no empty files -- preprocessing complete"; \
		fi; \
	else \
		echo "  src/: NOT GENERATED -- run make -f setup_sim.mk wipe + scripts-gen"; \
	fi
	@echo
	@echo "===== Run artifacts (cwd) ====="
	@ls -la transcript vsim.wlf modelsim.ini ram.srec 2>/dev/null | sed "s/^/  /" || true
	@if [ ! -f ram.srec ]; then echo "  (ram.srec missing -- run select-test before run-sim)"; fi
	@echo
