# METASAT SoC Project

This project builds and simulates a RISC-V SoC based on the NOEL-V core from GRLIB, targeting the Xilinx VCU118 development board.

## Structure

- **../../grlib/**: IP library providing the NOEL-V core and other components.
- **../../extra/**: Includes external Vortex accelerator integration.
- **rtl/**: Custom RTL components.
- **cfg/config_local.vhd**: Local configuration file.
- **config.vhd**: Configuration for the NOEL-V CPU cores.
- **vx_config.inc**: Configuration for the Vortex GPU accelerator.

## Features

- Quad-core RISC-V NOEL-V 64-bit core.
- Integration of Vortex GPU accelerator.
- DDR4 memory via Xilinx MIG.
- GRETH Ethernet via SGMII.

## Targets

| Target           | Description                             |
|------------------|-----------------------------------------|
| `metasat-sim`    | Build and run simulation                |
| `metasat-synth`  | Synthesize with Vivado (generates bitstream) |
| `metasat-vivado` | Open Vivado project                     |
| `vortex`         | Generate Vortex integration files       |
| `patch_vortex_sim` | Patch simulation makefile for Vortex |
| `vortex-clean`   | Clean Vortex integration files          |

## Prerequisites

- **Xilinx Vivado 2020.2** installed and sourced
- **Verilator v5.0** for generating Vortex sources
- **QuestaSim** for simulation

## Simulation

Run simulation:
```sh
make metasat-sim
````

## Synthesis

Synthesize the design and generate the FPGA bitstream:

```sh
make metasat-synth
```

Open Vivado GUI:

```sh
make metasat-vivado
```

## Cleaning

To clean the Vortex files:

```sh
make vortex-clean
```

