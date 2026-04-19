# Lab 1 — FPGA Intro: LFSR Random-Number Slot Machine

**Course:** Digital Circuits Lab, NTU  
**Board:** Terasic DE2-115 (Cyclone IV E)  
**Language:** SystemVerilog

---

## Overview

The design implements a **slot-machine-style random number generator** driven by a **16-bit LFSR (Linear Feedback Shift Register)**. Pressing `i_start` causes the displayed number to "roll" through random values with increasing pause intervals; releasing and re-pressing locks in a result.

The lab also served as an introduction to **synthesizable SystemVerilog style** — strict `_r` / `_w` register naming, no inferred latches, clean FSM structure.

---

## How It Works

### FSM (`src/Top.sv`)

Three states:

| State | Behaviour |
|-------|-----------|
| `S_IDLE` | Display `0`; LFSR advances every cycle to build entropy. `i_start` → `S_GEN`. |
| `S_GEN` | Output changes every `threshold` clock cycles, cycling through LFSR values. Threshold increases every 10 outputs (slowing the roll). After 20 changes → `S_HOLD`. |
| `S_HOLD` | Output is frozen. `i_start` → `S_GEN` (new roll). |

### LFSR

Taps on bits `[0, 2, 3, 5]` of a 16-bit register (Galois form):

```systemverilog
seed_next = {seed[0] ^ seed[2] ^ seed[3] ^ seed[5], seed[15:1]};
```

The seed keeps advancing even in `S_IDLE`, so the starting value of each roll is non-deterministic from the user's perspective.

### Timing

- Initial display interval: `INIT_THRESHOLD = 1_000_000` cycles (20 ms at 50 MHz).
- After the 10th output change, the interval grows by `DELTA_THRESHOLD = 500_000` cycles per step, making the roll visually "slow down" before stopping.

---

## Repository Layout

```
lab01_fpga_intro/
├── src/
│   ├── Top.sv              # Top-level module (LFSR + FSM)
│   └── DE2_115/            # Pin wrapper, seven-segment decoder, SDC
├── sim/
│   ├── tb_Top.sv           # SystemVerilog testbench
│   ├── Top_test.sv         # Alternative SV test
│   └── Top_test.py         # Python-based simulation helper
├── include/
│   └── LAB1_include.sv     # Common include (if any)
└── lint/
    └── Makefile            # nLint / SpyGlass invocation
```

---

## Build & Simulate

### Quartus synthesis

Open the project (`.qpf` / `.qsf`) in **Quartus II**, select **EP4CE115F29C7**, compile, and program.

### VCS simulation

```bash
cd sim
vcs tb_Top.sv ../src/Top.sv -full64 -R -debug_access+all -sverilog +access+rw
# Open waveform viewer (nWave or DVE) to inspect signals
```

### Lint (SpyGlass / nLint)

```bash
cd lint && make
```

Common warnings to resolve before synthesis: combinational loop (22011), inferred latch (23003), incomplete case (23007).
