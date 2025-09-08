# ESTU — Enabling Spiking Transformers on Ultra-Low-Power FPGAs

**ESTU** is a tiny SoC for edge AI that runs a **spiking transformer** on a Lattice **iCE40UP5K**.  
It combines a microcode-programmable accelerator, a **SERV** RISC-V softcore, and configurable **encoding/decoding** slots.  
This repo contains RTL, firmware, simulation testbenches, and scripts to build, simulate, flash, and run ESTU on hardware.

---

## Table of Contents
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Quick Start](#quick-start)
- [Generate Model → HW Artifacts](#generate-model--hw-artifacts)
- [Simulation](#simulation)
- [Build, P&R and Program](#build-pr-and-program)
- [Firmware Overview](#firmware-overview)
- [UART](#uart)
- [Makefile Targets](#makefile-targets)
- [Troubleshooting](#troubleshooting)
- [Citation](#citation)
- [License](#license)

---

## Repository Layout

```

MAIN\_ESTU/
├─ firmware/                 # RISC-V bare-metal firmware 
│  ├─ src/                   # sources: main.c, peripherals.h, constants.h, ...
│  ├─ exe.elf exe.hex ...    
│  └─ Makefile
├─ flash/                    # flash tools 
│  ├─ bin\_gen.c  bin\_gen
│  └─ flash\_program.sh
├─ logs/                     
├─ output/                   # synth / P\&R outputs (json, asc, bin)
├─ rtl/
│  ├─ estu/                  # accelerator (top, mmu, datapath, include)
│  ├─ serv/                  # SERV core
│  ├─ servant/               # SoC wrapper + on-chip peripherals
│  └─ ...
├─ scripts/Python/           # model → hardware files
│  ├─ InstructionGenerator/  # microcode generator (instr\_mem.txt)
│  ├─ init/ weights/ delta/  # generated init/weights/delta files
│  ├─ data/                  # golden\_txns.json / .hex
│  ├─ sim/ mem/              # flash.txt
│  ├─ conv\_json\_to\_hex.py
│  ├─ IntegerSpikeTransformer.ipynb
│  └─ serialLine.py
├─ sim/
│  ├─ tb/                    # tb\_soc{,*psim}.v + SB*\* OSC models + UART decoder
│  ├─ cells\_sim/ mem/
│  └─ ...
├─ work/                     # waveforms (.vcd) and GTKWave views
└─ Makefile                  # top-level flow (build/sim/flash/program)

````

---

## Prerequisites

- Linux (Tested on Ubuntu24.04 and AlmaLinux 9.6)
- **OSS-CAD-Suite** (Yosys, nextpnr-ice40, icepack, iceprog, etc.)
- **RISC-V GNU Toolchain** (bare-metal **riscv32-unknown-elf**, Newlib)
- Utilities: `python3` (with `numpy`, `pyserial`, `jupyter`), `minicom`, `make`, `gcc`

> We use OSS-CAD version 2023-07-28

---

## Environment Setup

### Install OSS-CAD-Suite 

```bash
# Download the tar.xz for Linux x86-64 from the official releases page
tar xf oss-cad-suite-*.tar.xz -C $HOME
source $HOME/oss-cad-suite/environment

# Sanity checks
yosys -V
nextpnr-ice40 --version
````

### Build the RISC-V toolchain (ELF/Newlib)
Additionally, a RISC-V cross-compiler is required to compile the firmware. If your system does not already include it, execute the following commands or refer to the riscv-gnu-toolchain page https://github.com/riscv-collab/riscv-gnu-toolchain
```bash
git clone https://github.com/riscv/riscv-gnu-toolchain --recursive
cd riscv-gnu-toolchain/
./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32
sudo make
```

---

## Quick Start

```bash

# 0) Build bitstream
source $HOME/oss-cad-suite/environment
make build

# 2) Program the iCEBreaker board
make prog

# 3) Receive inference results via UART (3 MBaud)
make listen    # edit the serial port in the Makefile if needed
```

---

## Generate Model → HW Initialization files

Run `scripts/Python/IntegerSpikeTransformer.ipynb`. It emits:

* **Delta-modulator init files** → `scripts/Python/delta/`
* **Weights** for integer memories → `scripts/Python/weights/`
* **Inputs to process** → `scripts/Python/init/`
* **Golden transactions** → `scripts/Python/data/golden_txns.json`
  Each entry has:

  * `ts`: timestep of the transaction
  * `op_id`: unique instruction identifier (helps align with the expected microcode)
  * `mem`: packed write-enables `{wr_en_intmem1, wr_en_intmem2, wr_en_sm1, wr_en_sm2}`
  * `data`: payload to be written

Convert JSON → hex for verification sims:

```bash
cd scripts/Python
python3 conv_json_to_hex.py data/golden_txns.json   # → data/golden_txns.hex
```

**Instruction memory (microcode):**
Run `scripts/Python/InstructionGenerator/instruction_generator.py`.
It produces `instr_mem.txt`, used to initialize the accelerator’s instruction BRAM.

**Flash image:**
The notebook creates `scripts/Python/sim/mem/flash.txt`.
Then:

```bash
# Create a C array from flash.txt
python3 flash/generate_carray.py scripts/Python/sim/mem/flash.txt > flash/flash_input.txt

# Build the small tool (if not yet built)
gcc -O2 -o flash/bin_gen flash/bin_gen.c

# Produce the binary and program the external flash
bash flash/flash_program.sh
```

> The external flash is written **contiguously** starting from address **2^20 = 1048576** (see `firmware/src/constants.h`).

---

## Simulation

Behavioral testbenches are located in `sim/tb`.

### Raw simulation

```
make simulate
# outputs VCD at work/tb_soc.vcd (and loads a saved GTKWave view)
```

### Verification mode (checks memory writes vs. golden file)

```
make simulate VFLAGS="-DVERIFICATION"
# Requires scripts/Python/data/golden_txns.hex
```

### Post-synthesis (gate-level) simulation

```
make psimulate
```

---

## Build, P\&R and Program

### Synthesis + Place & Route + Bitstream

```
make build
```

Default Yosys flags:

* `-dsp`
* `-abc9`
* `-flatten`

Device: **iCE40UP5K-SG48** 

### Program the FPGA

```
make prog
```

### Seed sweep (Fmax exploration)

```
make build-best
```

This brute-force search tries seeds `1..100` and selects the best `.asc`.
Use only when you really need extra MHz. It is time-consuming since it execute 100 different place and route in a very congested design.

---

## Firmware Overview

Default firmware: `firmware/src/main.c` (bare-metal).
Flow:

1. Wait for the **uBUtton** on iCEBreaker.
2. Init UART.
3. **Weights** load from SPI flash to INT MEM1/2:

   ```c
   DEV_WRITE(ESTU_WREN, 1);
   read_spi(INT_MEM_1_ADDR, INT_MEM1_ID, WEIGHTS_SIZE_1);
   DEV_WRITE(ESTU_WREN, 2);
   read_spi(INT_MEM_2_ADDR, INT_MEM2_ID, WEIGHTS_SIZE_2);
   DEV_WRITE(ESTU_WREN, 0); 
   ```
4. Configure accelerator and start first inference; then initialize the interrupt to repeat the inference at the selected inference frequency.

**Acceleratore routine:**

```c
DEV_WRITE(ESTU_NUM_INSTRUCTIONS, NUM_INSTRUCTIONS);
DEV_WRITE(ESTU_START_INFERENCE, 1);              // auto-cleared by HW
read_spi(INPUT_BUFFER_ADDR, INPUT_BUFFER_ID, INPUT_CHANNELS);
int16_t y = exec_inference();                    // waits done bit on ESTU_DATA
uart_send(y);
```

**ISR** repeats the above and finally enables clock gating:

```c
DEV_WRITE(CLOCK_GATE_CTRL, 1);
```

>The timer connected to the interrupt controller increments at the frequency of the LFOSC: 10kHz. 

## UART

* **Baud rate:** **3,000,000** (3 MBaud)
* **Quick listener (minicom):**

  ```
  make listen
  ```

  This opens `/dev/ttyUSB1` by default and logs to `output/serial.txt`.
  Change the port in the Makefile or run:

  ```
  minicom -b 3000000 -D /dev/ttyUSB0 -H -C output/serial.txt
  ```
* Python alternative: `scripts/Python/serialLine.py`.

---

## Makefile Targets

* `build` — synthesize, P\&R, and generate bitstream
* `prog` — program FPGA with `iceprog`
* `simulate` — behavioral simulation (`VFLAGS="-DVERIFICATION"` to enable an additional verification)
* `psimulate` — post-synthesis simulation
* `build-best` — sweep seeds in place and route process
* `listen` — open UART @ 3 MBaud (minicom)
* `clean` / `clean-logs` — cleanup artifacts and logs

---

## Troubleshooting

* **nextpnr fails timing** → try a different `--seed` or `make build-best`.
  For exploratory builds add `--timing-allow-fail`.
* **No serial output** → ensure that the correct port is selected and the Baud Rate is equal to 3 Mega Baud.

---

## Citation

