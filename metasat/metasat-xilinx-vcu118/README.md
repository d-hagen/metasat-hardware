# METASAT SoC

## Configuration

This directory contains the official configuration of the METASAT platform for the [VCU118](https://www.xilinx.com/products/boards-and-kits/vcu118.html) FPGA.
It can be customized to suit individual user requirements.
Note that changing certain parameters without adjusting related settings may cause the platform to malfunction.

After any change in the configuration is recommended to run `make clean; make distclean` to regenerate all target files.

### CPU Multicore
To modify the CPU multicore unit update the [config.vhd](config.vhd) file.
The following is a non-exhaustive list of parameters than can be changed:
* `CFG_NCPU`: Number of CPU cores (default: 4)
* `CFG_CFG`: Change the CPU configuration (default: HP)
* `CFG_L2_EN`: Enable/Disable the L2 unit (default: 1)

### SPARROW
TBD

### Vortex GPU
In [config.vhd](config.vhd), set `CFG_VX_EN` to `1` (enabled) or `0` (disabled) to enable or disable the Vortex GPU.
The default value is `1`.

The following Vortex parameters can be configured in [vx_config.inc](vx_config.inc):
* `NUM_CORES`: Number of GPU cores (default: 8)
* `NUM_WARPS`: Number of warps per GPU core (default: 4)
* `NUM_THREADS`: Number of threads per warp (default: 4)

## Synthesis

To generate the METASAT bitstream run `make metasat-synth` in `metasat/metasat-xilinx-vcu118`.
Alternatively, run `make metasat-vivado` to launch the Vivado GUI with the project loaded.

Check the [README.md](../fpga/README.md) in `metasat/fpga` for more details on how to program the FPGA and use the platform.

### Requirements
* [Vivado 2020.2](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html)
* [Verilator 5.040](https://github.com/verilator/verilator/tree/v5.040)
* [GRMON4 Evaluation](https://www.gaisler.com/products/grmon4)

## Simulation
When simulating for the first time it is required to build the proprietary Xilinx IPs. 
To do so, run `make map_xilinx_7series_lib` in `metasat/metasat-xilinx-vcu118`.

Afterwards, for every simulation execute the following steps:
* Copy the target test (in .srec format) to `ram.srec`
* Run `make metasat-sim`
* Run `make vsim-launch`

### Requirements
* [Verilator 5.040](https://github.com/verilator/verilator/tree/v5.040)
* `Questa Sim-64 2022.4`

