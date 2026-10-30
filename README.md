# ARC4 Stream-Cipher Hardware

SystemVerilog implementation and verification files for the ARC4 stream-cipher project.

## Repository structure

- `rtl/` — synthesizable ARC4, initialization, KSA, PRGA, and FPGA top-level modules
- `rtl/memory/` — generated memory modules required by the design
- `tb/` — RTL and post-synthesis testbenches
- `test_vectors/` — memory initialization files and expected test data
- `sim/` — ModelSim project and generated simulation artifacts
