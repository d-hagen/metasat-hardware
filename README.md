# METASAT Hardware

## Generating Vortex Verilator files

The simulation of Vortex using Verilator has been tested with Verilator 5.025 devel rev v5.024-86-gd4c3e35f9, which has been installed from the [Verilator GitHub repository](https://github.com/verilator/verilator).
Older versions of Verilator do not support some of the SystemVerilog features used in Vortex.

To properly use the simulation a Vortex configuration file is necessary, such as the one in `metasat-hardware/metasat/metasat-xilinx-vcu118/vx_config.inc`.

From this repository top directory:
```bash
cd extra/vortex/hw/syn/soc
cp metasat-hardware/metasat/metasat-xilinx-vcu118/vx_config.inc .
make verilator VX_CONFIG=vx_config.inc
```

The resulting files are then in a new `obj_dir` folder created by Verilator.

Additionally, the input parameters from Vortex can be modified setting the AXIDW and AXIID variables in the Makefile, although by default they are set to the values used in the METASAT platform.



