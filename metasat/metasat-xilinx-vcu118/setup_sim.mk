# QuestaSim Simulation Setup — uni machine
#
#   cd metasat/metasat-xilinx-vcu118
#   make -f setup_sim.mk all                       # one-time setup (~15 min)
#   make -f setup_sim.mk TEST=bare     run-sim     # GPU start/stop sanity
#   make -f setup_sim.mk TEST=nospawn  run-sim     # single-thread compute
#   make -f setup_sim.mk TEST=spawn1   run-sim     # spawn library, num_tasks=1
#   make -f setup_sim.mk TEST=parallel run-sim     # multi-warp parallel compute

# ---- Environment setup ----
export PATH := /opt/siemens/questasim/bin:$(PATH)
export SALT_LICENSE_SERVER := 1717@questa.fib.upc.edu

# ---- User-configurable paths ----
UNISIM_SRC   ?= /dades/dan.joshua.hagen/unisims
SIM_DIR      ?= $(CURDIR)
GRLIB        ?= ../../grlib
EVAL_DIR     ?= ../../extra/vortex/eval
TEST         ?= bare
WAVE_DO      ?= wave.do

# ---- Derived paths ----
UNISIM_LIB   = $(UNISIM_SRC)/unisim
AXI_SIM_DIR  = $(GRLIB)/lib/gaisler/sim

REPO_ROOT_DIR := $(abspath $(SIM_DIR)/../..)
LOG_FILE       = $(REPO_ROOT_DIR)/sim-$(TEST)-$(shell date +%Y%m%d-%H%M%S).log

.PHONY: all check-paths compile-unisim scripts-gen map-unisim \
        stub-libs widen-grlib-axi-id select-test compile-rtl run-sim run-wave \
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
	@echo "=== Selecting memory test (host-only DMA, SIZE=1024) ==="
	cp $(EVAL_DIR)/memory/gpu-memory.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),memory-light)
	@echo "=== Selecting memory-light test (host-only DMA, SIZE=16) ==="
	cp $(EVAL_DIR)/memory/gpu-memory-light.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),parallel)
	@echo "=== Selecting parallel test (multi-warp PoC, raw intrinsics, SIZE=1024) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-parallel.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),parallel-light)
	@echo "=== Selecting parallel-light test (multi-warp PoC, raw intrinsics, SIZE=16) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-parallel-light.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),bare)
	@echo "=== Selecting bare test (GPU start/stop only) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-bare.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),nospawn)
	@echo "=== Selecting nospawn test (single-thread, no spawn) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-nospawn.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),spawn1)
	@echo "=== Selecting spawn1 test (spawn 1 task) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-spawn1.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),evaluation)
	@echo "=== Selecting evaluation test (vx_spawn_threads library, SIZE=1024) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),evaluation-light)
	@echo "=== Selecting evaluation-light test (vx_spawn_threads library, SIZE=16) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-light.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),evaluation-s15)
	@echo "=== Selecting evaluation-s15 test (vx_spawn_threads, SIZE=15, non-multiple-of-4 -> spawn remainder path) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-s15.srec $(SIM_DIR)/ram.srec
else ifeq ($(TEST),evaluation-s15-buggyspawn)
	@echo "=== Selecting evaluation-s15-buggyspawn (A/B control: BUGGY spawn + copy fix; expected to FAIL at position 12) ==="
	cp $(EVAL_DIR)/evaluation/gpu-evaluation-s15-buggyspawn.srec $(SIM_DIR)/ram.srec
else
	@echo "ERROR: Unknown TEST=$(TEST)."
	@echo "  memory | memory-light | bare | nospawn | spawn1 | parallel | parallel-light | evaluation | evaluation-light"
	@exit 1
endif

# ---- Step 8: Compile all RTL (GRLIB + NOEL-V + Vortex) ----
compile-rtl:
	@echo "=== Compiling RTL ==="
	@touch .vortex   # prevent vortex rule from running gen_sources.sh (no Verilator here)
	cd $(SIM_DIR) && $(MAKE) metasat-sim

# ---- Step 9: Run simulation ----
VSIMOPT_FAST = -voptargs="+acc -nowarn 1" -do "run -all; quit -f" testbench

# Waveform capture: +acc keeps signals accessible; wave.do logs the schedule
# unit (warp_pcs, active/stalled warps, tmasks) and AFU busy, then runs 20ms.
# Ctrl-C the sim to flush the WLF early and inspect a partial wave.
WAVE_FILE     = $(REPO_ROOT_DIR)/sim-wave-$(TEST)-$(shell date +%Y%m%d-%H%M%S).wlf
VSIMOPT_WAVE  = -voptargs="+acc -nowarn 1" \
                -wlf $(WAVE_FILE) \
                -do "$(SIM_DIR)/$(WAVE_DO)" \
                testbench

run-sim: select-test
	@echo "=== Launching simulation ==="
	@echo "=== Log file: $(LOG_FILE) ==="
	@date '+=== Start: %F %T ===' | tee $(LOG_FILE)
	@cd $(SIM_DIR) && $(MAKE) sim-run VSIMOPT='$(VSIMOPT_FAST)' 2>&1 | tee -a $(LOG_FILE)
	@date '+=== End:   %F %T ===' | tee -a $(LOG_FILE)
	@echo "=== Sim finished. Full log: $(LOG_FILE) ==="

run-wave: select-test
	@echo "=== Launching waveform simulation (20ms, +acc) ==="
	@echo "=== WLF: $(WAVE_FILE) ==="
	@echo "=== Log file: $(LOG_FILE) ==="
	@date '+=== Start: %F %T ===' | tee $(LOG_FILE)
	@cd $(SIM_DIR) && $(MAKE) sim-run VSIMOPT='$(VSIMOPT_WAVE)' 2>&1 | tee -a $(LOG_FILE)
	@date '+=== End:   %F %T ===' | tee -a $(LOG_FILE)
	@echo "=== Done. Open waveform: vsim -view $(WAVE_FILE) ==="

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
	@echo "  run-wave        - Launch simulation with waveform capture (wave.do, 20ms)"
	@echo "  rebuild         - Re-do scripts-gen + compile-rtl after config change"
	@echo "  wipe            - Drop cached libs; keep UNISIM + pre-generated src/"
	@echo "  nuke            - Drop everything including UNISIM (~15min to rebuild)"
	@echo "  check-config    - Report CPU + GPU config"
	@echo "  check-all       - Config + library timestamps + corruption probes"
	@echo ""
	@echo "Variables:"
	@echo "  UNISIM_SRC      - Path to unisims/ folder  (default: /dades/dan.joshua.hagen/unisims)"
	@echo "  TEST            - memory | memory-light | evaluation | evaluation-light  (default: memory)"
