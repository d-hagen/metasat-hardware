# GRLIB

This repository is based on **Frontgrade Gaisler's GRLIB GPL release**.
GRLIB is a library of IP cores for designing systems on chip (SoC) with LEON and NOEL processors.
This project integrates and extends the GRLIB GPL sources with additional features, FPGA support, and the SPARROW accelerator.

For the original GRLIB GPL release and documentation, see:
[Gaisler GRLIB GPL Release](https://www.gaisler.com/grlib-ip-library).

## Branches

This repository uses the following branches for organization and development:

* **`grlib-gpl`**
  Contains the base sources from the official GRLIB GPL release.

* **`sparrow`**
  Based on the GRLIB GPL release with the **SPARROW AI accelerator** integrated.

* **`extra-fpga`**
  Based on the GRLIB GPL release with additional files for FPGA support.
  Currently supported FPGA targets:

* **`main`**
  The main branch containing the full integration of all features.

## SPARROW

**SPARROW** is a SIMD AI accelerator tailored for space applications.
It provides a low-cost, hardware/software co-designed microarchitecture optimized for AI operations in space processors.

Reference:
```bibtex
@inproceedings{bonet2022sparrow,
  title={SPARROW: A low-cost hardware/software co-designed SIMD microarchitecture for AI operations in space processors},
  author={Sol{\'e} Bonet, Marc and Kosmidis, Leonidas},
  booktitle={2022 Design, Automation \& Test in Europe Conference \& Exhibition (DATE)},
  pages={1139--1142},
  year={2022},
  organization={IEEE}
}
````

## Repository Organization

The repository is organized into the following directories:

* **`bin/`**
  Utility scripts and helper tools (generic collection of build and support scripts).

* **`boards/`**
  Board-specific files for the supported development boards.

* **`designs/`**
  Top-level files for supported cores and boards.
  Each subdirectory here typically represents a complete design (SoC + board integration).

* **`doc/`**
  Documentation and guides for the IP library.

* **`lib/`**
  GRLIB source files.

* **`software/`**
  Software components, drivers, or test programs associated with the hardware designs.

## Usage

To synthesize or simulate a given design:

1. Navigate to the corresponding subdirectory under `designs/`.
2. Check the `README.md` inside that directory for **specific instructions** on:

   * Supported tools (simulation/synthesis).
   * Required setup.
   * Board-specific workflows.

## References

* [Gaisler GRLIB GPL Release](https://www.gaisler.com/grlib-ip-library)
* Solé Bonet, M. & Kosmidis, L. (2022). *SPARROW: A low-cost hardware/software co-designed SIMD microarchitecture for AI operations in space processors.*
  In **2022 Design, Automation & Test in Europe Conference & Exhibition (DATE)** (pp. 1139–1142). IEEE.

## License

This project includes the GRLIB GPL release and is distributed under the terms of the GPL license.
Refer to the LICENSE file for details.
