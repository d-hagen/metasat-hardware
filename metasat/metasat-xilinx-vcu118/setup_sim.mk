# QuestaSim Simulation Setup — uni machine
#
# This Makefile is part of the sim/uni-machine branch ONLY. It is
# machine-specific (QuestaSim license, UNISIM path, RTL-sim helpers)
# and must NOT be merged to the release branch.
#
# Typical workflow on the uni laptop:
#   cd metasat/metasat-xilinx-vcu118
#   make -f setup_sim.mk all                            # one-time setup (~15 min)
#   make -f setup_sim.mk TEST=memory-light run-sim      # fast memory test
#   make -f setup_sim.mk TEST=memory run-sim            # full memory test
#   make -f setup_sim.mk TEST=evaluation-light run-sim  # fast evaluation (with kernel)
#   make -f setup_sim.mk TEST=evaluation run-sim        # full evaluation

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

# Per-test sim output log: written to the repo root, named per test + timestamp
# so each run gets its own file. e.g. sim-memory-light-20260603-143012.log
REPO_ROOT_DIR := $(abspath $(SIM_DIR)/../..)
LOG_FILE       = $(REPO_ROOT_DIR)/sim-$(TEST)-$(shell date +%Y%m%d-%H%M%S).log

.PHONY: all check-paths compile-unisim scripts-gen map-unisim \
        stub-libs widen-grlib-axi-id select-test compile-rtl run-sim \
        wipe nuke rebuild check-config check-all clean-unisim help

all: check-paths compile-unisim scripts-gen map-unisim stub-libs widen-grlib-axi-id select-test compile-rtl
	@echo ""
	@echo "=== Setup complete ==="
	@echo "Run:  make -f setup_sim.mk run-sim"
	@echo "      make -f setup_sim.mk TEST=evaluation run-sim"

# ---- Step 1: Verify prerequisites ----
check-paths:
	@echo "=== Checking prerequisites ==="
	@which vlib  > /dev/null 2>&1 || (echo "ERROR: QuestaSim not on PATH" && exit 1)
	@which vcom  > /dev/null 2>&1 || (echo "ERROR: QuestaSim not on PATH" && exit 1)
	@test -d "$(UNISIM_SRC)" || (echo "ERROR: UNISIM_SRC=$(UNISIM_SRC) not found." && exit 1)
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

# ---- Step 6: Widen GRLIB sim-model AXI ID storage ----
#
# Why this exists:
#   grlib/lib/gaisler/sim/{aximem,axirep,axixmem}.vhd hard-code their
#   internal write/read queue id fields as std_logic_vector(3 downto 0).
#   The metasat SoC sets AXI_ID_WIDTH = 32 (grlib/lib/grlib/amba/amba.vhd:54,
#   also enforced by the parent Makefile's patch-id-width rule). With the
#   wider AXI types, all three files emit "length mismatch" errors during
#   vcom on the idle-constant aggregates and the
#     rq(i).id := axisi.ar.id
#   style assignments. aximem is the one actually on the Vortex memory
#   path; axirep and axixmem live in the same gaisler sim library and
#   compile alongside it, so all three must be patched for the build to
#   succeed at all under AXI_ID_WIDTH=32.
#
#   Beyond elaboration: once silently truncated to 4 bits, IDs from
#   outstanding cluster mem xacts collide on their bottom 4 bits — aximem
#   matches W data to AW entries by ID equality (aximem.vhd:197), so
#   collisions misroute write data, one outstanding write never sees its
#   matching W beat, no bvalid is issued, Vortex's fence (vx_start.S)
#   stalls forever and the AFU sits in STATE_RUN with vx_busy=1.
#
# What it does:
#   In each of the three files, replaces the two
#     id: std_logic_vector(3 downto 0)
#   field declarations with
#     id: std_logic_vector(AXI_ID_WIDTH-1 downto 0)
#   (symbolic — tracks any future GRLIB AXI_ID_WIDTH change), and rewrites
#   the two idle-constant aggregates
#     id => "0000"   ==>   id => (others => '0')
#   AXI_ID_WIDTH is already in scope in all three via `use grlib.amba.all`.
#
# Idempotency:
#   Both sed regexes match only the unpatched 4-bit form, so re-running
#   is a no-op. Safe to call from `all`, `rebuild`, or standalone.
widen-grlib-axi-id:
	@echo "=== Widening GRLIB sim-model AXI ID storage to AXI_ID_WIDTH ==="
	@for f in $(AXI_SIM_DIR)/aximem.vhd $(AXI_SIM_DIR)/axirep.vhd $(AXI_SIM_DIR)/axixmem.vhd; do \
	  if [ ! -f "$$f" ]; then \
	    echo "ERROR: $$f not found"; exit 1; \
	  fi; \
	  sed -i \
	      -e 's/id: std_logic_vector(3 downto 0)/id: std_logic_vector(AXI_ID_WIDTH-1 downto 0)/g' \
	      -e 's/id => "0000"/id => (others => '\''0'\'')/g' \
	      "$$f"; \
	  if grep -q 'id: std_logic_vector(3 downto 0)\|id => "0000"' "$$f"; then \
	    echo "ERROR: $$f still has unpatched 4-bit id forms"; exit 1; \
	  fi; \
	  echo "OK: $$f patched (or already in widened form)"; \
	done

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
# Pre-generated Vortex sources are pulled in via dirs.txt + hw/syn/soc/src/.
# No Verilator needed on this machine — sources come from the VM via git.
compile-rtl:
	@echo "=== Compiling RTL ==="
	@touch .vortex   # prevent vortex rule from running gen_sources.sh (no Verilator here)
	cd $(SIM_DIR) && $(MAKE) metasat-sim

# ---- Step 9: Run simulation ----
# Output streamed to console AND tee'd to a per-test timestamped log file in repo root.
#
# Speed-tuned VSIMOPT override (sim-branch only — pass/fail mode, no debug):
#   -voptargs="-O5 -nowarn 1"  Replace GRLIB's default "+acc" (which DISABLES
#                              optimization for signal visibility) with -O5.
#                              Biggest single speedup; trades waveform-debug
#                              ability for ~2-5x faster sim.
#   -do "run -all; quit -f"    Same as GRLIB's runvsim.do but inline (replacing
#                              GRLIB's stdin redirect, since VSIMOPT can't carry "<").
#   -quiet                     Suppress vsim's own status chatter.
#   testbench                  GRLIB's SIMTOP for this design.
# Note: -nowlf was dropped — not recognized by this QuestaSim version.
# Since our -do doesn't issue any `log`/`wave` commands, the .wlf file stays
# essentially empty anyway, so disk I/O is negligible.
VSIMOPT_FAST = -voptargs="+acc -nowarn 1" -do "run -all; quit -f" -quiet testbench

run-sim: select-test
	@echo "=== Launching simulation ==="
	@echo "=== Log file: $(LOG_FILE) ==="
	@date '+=== Start: %F %T ===' | tee $(LOG_FILE)
	@cd $(SIM_DIR) && $(MAKE) sim-run VSIMOPT='$(VSIMOPT_FAST)' 2>&1 | tee -a $(LOG_FILE)
	@date '+=== End:   %F %T ===' | tee -a $(LOG_FILE)
	@echo "=== Sim finished. Full log: $(LOG_FILE) ==="

# ---- Utilities ----
clean-unisim:
	rm -rf $(UNISIM_LIB)

# wipe: clear cached build state after config edits, keep UNISIM + pre-generated src/
wipe:
	@echo "=== Wiping cached build state (work, libs, make.*) ==="
	rm -rf work libs make.work make.vsim make.bem
	@echo "=== Keeping .vortex marker + pre-generated Vortex src/ (no Verilator here) ==="
	@echo "=== Next: make -f setup_sim.mk rebuild ==="

# nuke: maximal wipe — repo build state + compiled libraries + UNISIM + run artifacts
nuke:
	@echo "=== NUCLEAR wipe: repo build state ==="
	rm -rf work libs make.work make.vsim make.bem
	rm -rf vortex grlib gaisler techmap noelv sparrow secureip unisims_ver modelsim
	rm -f modelsim.ini
	rm -f transcript vsim.wlf vsim*.dbg vsim*.vstf vsim_stacktrace.vstf .vsim*
	rm -f ram.srec
	rm -rf $(UNISIM_SRC)/unisim
	@echo "=== NUKE complete. Run: make -f setup_sim.mk all ==="

# rebuild: bundle the incremental build pipeline (skips UNISIM compile)
rebuild: scripts-gen map-unisim stub-libs widen-grlib-axi-id select-test compile-rtl
	@echo "=== rebuild complete; run: make -f setup_sim.mk TEST=<name> run-sim ==="

# check-config: report CPU + GPU config from source vs build artifacts
check-config:
	@echo
	@echo "===== CPU config (config.vhd) ====="
	@grep -E "^[[:space:]]*constant (CFG_NOELV|CFG_NCPU|CFG_CFG|CFG_L2_EN|CFG_L2_SIZE|CFG_L2_WAYS|CFG_VX_EN|CFG_FPNPEN)" config.vhd
	@echo
	@echo "===== GPU config (vx_config.inc) ====="
	@grep -E "^[[:space:]]*(XLEN|NUM_CORES|NUM_WARPS|NUM_THREADS|NUM_BARRIERS|EXT_F_EN|EXT_M_EN|DBG_TRACE_EN)[[:space:]]*=" vx_config.inc
	@echo
	@echo "===== Build state — Vortex preprocessed sources ====="
	@if [ -f ../../extra/vortex/hw/syn/soc/sources.txt ]; then \
		echo "  sources.txt defines:"; \
		grep -E "\+define\+(NUM_CORES|NUM_CLUSTERS|NUM_WARPS|NUM_THREADS|XLEN|EXT)" ../../extra/vortex/hw/syn/soc/sources.txt | sed "s/^/    /"; \
	else \
		echo "  sources.txt: not generated"; \
	fi
	@echo

# check-all: check-config + library timestamps + corruption probes
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
	@echo "===== Vortex preprocessed src/ ====="
	@if [ -d ../../extra/vortex/hw/syn/soc/src ]; then \
		n=$$(ls ../../extra/vortex/hw/syn/soc/src/ 2>/dev/null | wc -l); \
		echo "  src/: $$n files"; \
		empty=$$(find ../../extra/vortex/hw/syn/soc/src/ -type f -size 0 2>/dev/null | wc -l); \
		if [ "$$empty" -gt 0 ]; then \
			echo "  >>> $$empty empty files in src/ — pull from git or regenerate on VM <<<"; \
		else \
			echo "  no empty files — preprocessed sources OK"; \
		fi; \
	else \
		echo "  src/: NOT PRESENT — pull from git or regenerate on VM"; \
	fi
	@echo

help:
	@echo "QuestaSim Simulation Setup — uni machine"
	@echo ""
	@echo "Targets:"
	@echo "  all             - Full setup: UNISIM, scripts, stub-libs, RTL compile"
	@echo "  run-sim         - Launch simulation (selects test based on TEST=)"
	@echo "  rebuild         - Re-do scripts-gen + compile-rtl after config change"
	@echo "  wipe            - Drop cached libs; keep UNISIM + pre-generated src/"
	@echo "  nuke            - Drop everything including UNISIM (~15min to rebuild)"
	@echo "  check-config    - Report CPU + GPU config"
	@echo "  check-all       - Config + library timestamps + corruption probes"
	@echo ""
	@echo "Variables:"
	@echo "  UNISIM_SRC      - Path to unisims/ folder  (default: /dades/dan.joshua.hagen/unisims)"
	@echo "  TEST            - memory | memory-light | evaluation | evaluation-light  (default: memory)"
