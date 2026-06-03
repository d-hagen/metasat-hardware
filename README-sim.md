# Sim machine — cheat sheet

Branch: `sim/uni-machine`. Personal use, copy-paste.

## First time / after VM regenerated artifacts

```bash
git pull
cd metasat/metasat-xilinx-vcu118
make -f setup_sim.mk wipe rebuild        # if UNISIM missing: make -f setup_sim.mk all
```

## Run tests (each logs to repo root: `sim-<TEST>-<timestamp>.log`)

```bash
time make -f setup_sim.mk TEST=memory-light run-sim
time make -f setup_sim.mk TEST=evaluation-light run-sim
time make -f setup_sim.mk TEST=memory run-sim
time make -f setup_sim.mk TEST=evaluation run-sim
```

The log file itself also has `=== Start: ... ===` / `=== End: ... ===` markers for absolute timestamps. The shell `time` prefix prints wall-clock elapsed after the command finishes.

## Abort mid-test

`Ctrl-C`. If the next run errors about libraries:
```bash
make -f setup_sim.mk wipe rebuild
```

## On the VM (after editing config or eval sources)

```bash
ssh vortex22
cd /home/dan/metasat-hardware
git checkout sim/uni-machine && git pull
bash scripts/regenerate_artifacts.sh
```

## Full reset (rare — only if `wipe rebuild` doesn't fix it)

```bash
make -f setup_sim.mk nuke          # also drops UNISIM, ~15 min to rebuild
make -f setup_sim.mk all
```

## Diagnostics

```bash
make -f setup_sim.mk check-all     # config + UNISIM + library timestamps + corruption probe
```
