# Sim setup — uni machine (branch `sim/uni-machine`)

This branch is for running RTL simulation of the cleaned-up Vortex 2.2
metasat SoC on the uni laptop in the lab. It is **NOT** for release —
do not merge into `main` or `vortex-2.2`.

What this branch adds on top of `vortex-2.2`:

- `metasat/metasat-xilinx-vcu118/setup_sim.mk` — QuestaSim sim harness
- `config.vhd` reduced to 1 NOEL-V core, `vx_config.inc` reduced to 1 GPU core
  (so the design fits and sims quickly on the laptop)
- Pre-built Vortex synthesis sources (`hw/syn/soc/src/`, `sources.txt`, `svlogsyn.txt`)
  — built on the VM, committed here so the sim machine doesn't need Verilator
- Pre-built SoC runtime library (`runtime/soc/libvortex.a` + generated headers)
- Pre-built eval test SRECs (memory + evaluation, full + light variants)
- `scripts/regenerate_artifacts.sh` — VM-side helper to rebuild and push everything

---

## On the sim machine — first time

```bash
# 1. Clone (or pull) the sim branch
cd ~/path/to/metasat-hardware                       # or git clone first
git fetch origin
git checkout sim/uni-machine
git pull

# 2. One-time setup: compile UNISIM + GRLIB scripts + stub libs + RTL
#    (~15 min, dominated by UNISIM compile)
cd metasat/metasat-xilinx-vcu118
make -f setup_sim.mk all
```

That gets you a fully built simulation environment. Then run any of:

```bash
# Fast tests (SIZE=16, ~seconds)
make -f setup_sim.mk TEST=memory-light run-sim
make -f setup_sim.mk TEST=evaluation-light run-sim

# Full tests (SIZE=1024, slower)
make -f setup_sim.mk TEST=memory run-sim
make -f setup_sim.mk TEST=evaluation run-sim
```

Test names:
- `memory` / `memory-light` — pure memory R/W test, no GPU kernel launch.
  Exercises driver, AXI, MMIO, buffer allocator.
- `evaluation` / `evaluation-light` — full end-to-end. Host uploads a Vortex
  kernel binary, launches it via `vx_start`, reads results back.

### Sim output is logged automatically

Every `run-sim` invocation streams the QuestaSim transcript to your terminal
AND tees it to a per-test, per-run log file in the repo root:

```
metasat-hardware/sim-memory-light-20260603-143012.log
metasat-hardware/sim-evaluation-20260603-143945.log
```

Filename pattern: `sim-<TEST>-<YYYYMMDD-HHMMSS>.log`. Each run gets its own
file (timestamped) so multiple runs of the same test don't overwrite. Logs
are gitignored.

## On the sim machine — when the VM has regenerated artifacts

```bash
cd ~/path/to/metasat-hardware
git pull                                            # gets the new artifacts
cd metasat/metasat-xilinx-vcu118
make -f setup_sim.mk wipe rebuild                   # rebuild RTL, keep UNISIM
make -f setup_sim.mk TEST=memory-light run-sim
```

`wipe` drops cached QuestaSim libraries (work/, libs/, make.*) but keeps the
~5 GB compiled UNISIM library. `rebuild` re-runs `scripts-gen` + `map-unisim`
+ `stub-libs` + `compile-rtl`.

## On the sim machine — when `config.vhd` or `vx_config.inc` is edited locally

Don't. Config changes require regenerating Vortex sources, which needs
Verilator, which isn't installed on the sim machine. Do them on the VM:

1. SSH into the VM, edit `config.vhd` / `vx_config.inc`
2. Run `bash scripts/regenerate_artifacts.sh` (auto-commits + pushes)
3. On the sim machine: `git pull && make -f setup_sim.mk wipe rebuild`

## Troubleshooting

### `compile-unisim` fails — QuestaSim not on PATH

`setup_sim.mk` exports `PATH := /opt/siemens/questasim/bin:$PATH` at the top.
If that path is wrong on this machine, edit line 21 of `setup_sim.mk` to
point at your QuestaSim install.

### `make ... run-sim` hangs forever / no output

Probably blocked on QuestaSim license. The harness exports
`SALT_LICENSE_SERVER := 1717@questa.fib.upc.edu`. Confirm the license server
is reachable (`ping questa.fib.upc.edu`); on a fresh terminal you may also
need to re-export this before running, since shell sessions don't persist
environment.

### `select-test` says "Unknown TEST=..."

Pick from: `memory`, `memory-light`, `evaluation`, `evaluation-light`.

### Sim fails immediately complaining about missing `ram.srec`

`select-test` copies the appropriate pre-built `.srec` to `ram.srec` in the
sim directory. If the eval SRECs aren't in the repo, the VM hasn't run
the regenerate script yet. Trigger a regen on the VM and `git pull` here.

### `make -f setup_sim.mk check-all` for diagnostics

Reports CPU + GPU config, UNISIM library status, compiled-library timestamps
(fresh vs stale relative to `vx_config.inc`), and probes for corrupted
(zero-byte) preprocessed sources. Useful when something feels off.

### Full reset

```bash
make -f setup_sim.mk nuke    # drops EVERYTHING including UNISIM (~15min to rebuild)
make -f setup_sim.mk all     # rebuilds from scratch
```

---

## On the VM — regenerating artifacts

```bash
ssh vortex22
cd /home/dan/metasat-hardware
git checkout sim/uni-machine
git pull
bash scripts/regenerate_artifacts.sh
```

The script: configures Vortex, regenerates synthesis sources, builds the
runtime library, builds all four SREC variants, then commits and pushes
to `origin/sim/uni-machine`. Whatever's pushed there is what the sim
machine pulls.

If you edited config files on the VM, commit those changes manually first
(the helper will pick them up in the same artifact commit).
