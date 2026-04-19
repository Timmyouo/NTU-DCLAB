# Lab 2 — RSA-256 Hardware Accelerator + Avalon/RS-232 Interface

**Course:** Digital Circuits Lab, NTU  
**Board:** Terasic DE2-115 (Cyclone IV E)  
**Language:** SystemVerilog / Verilog  
**Host tool:** Python 2/3 + `pyserial`

---

## Overview

Full hardware implementation of **256-bit RSA decryption** (modular exponentiation `y^d mod n`) on FPGA, integrated with a host PC via RS-232.

The design has three layers:

1. **`Rsa256Core`** — pure arithmetic datapath (Montgomery multiplication).
2. **`Rsa256Wrapper`** — Avalon-MM bus master that reads operands from the PC over RS-232, triggers the core, and sends back the result.
3. **Qsys system** — Avalon interconnect with an Intel RS-232 IP, wrapping the above as a custom master.

---

## Algorithm

### Montgomery Multiplication

RSA exponentiation is decomposed into repeated **Montgomery multiplications** to avoid large modular reduction:

```
result = a_pow_d mod n
```

Sub-modules instantiated inside `Rsa256Core`:

| Module | Role |
|--------|------|
| `RsaPrep` | Pre-compute `y · 2^256 mod n` (Montgomery domain entry) |
| `RsaMont` | One 256-bit Montgomery multiply step: `a · b · 2^-256 mod n` |

The FSM in `Rsa256Core` iterates 256 bits of `d` (private key), selecting at each bit whether to update the accumulator, following the standard **left-to-right binary exponentiation** algorithm.

### FSM

| State | Action |
|-------|--------|
| `S_IDLE` | Wait for `i_start` |
| `S_PREP` | Run `RsaPrep` to enter Montgomery domain |
| `S_MONT` | Loop 256 times, two Montgomery mults per bit (t², then m×t if bit=1) |
| `S_DONE` | Assert `o_finished`; output `o_a_pow_d` |

---

## Host Protocol (RS-232)

The wrapper (`Rsa256Wrapper`) orchestrates one decryption cycle in sequence:

```
PC → FPGA : 32 bytes (n, big-endian)
PC → FPGA : 32 bytes (e / d, big-endian)
PC → FPGA : 32 bytes (a / ciphertext, big-endian)
FPGA      : compute y^d mod n
FPGA → PC : 31 bytes (plaintext, leading zero omitted)
            then loop back to receive next ciphertext
```

Avalon read/write accesses the RS-232 IP status and data registers using the **two-wire (valid/ready) handshake** described in the Avalon specification.

---

## Repository Layout

```
lab02_rsa256/
├── src/
│   ├── Rsa256Core.sv           # Core FSM + Montgomery submodules
│   ├── Rsa256Wrapper.sv        # Avalon master + protocol controller
│   ├── DE2_115/                # Pin wrapper, SDC
│   └── tb_verilog/
│       ├── tb.sv               # Testbench for Rsa256Core
│       ├── test_wrapper.sv     # Testbench for Rsa256Wrapper
│       ├── PipelineCtrl.v      # Pipeline control helper
│       ├── PipelineTb.v        # Pipeline testbench utility
│       ├── wrapper_input.txt   # Hex input vectors for wrapper TB
│       └── wrapper_output.txt  # Expected output for wrapper TB
└── src/pc_python/
    ├── rs232.py                # Host serial script (send n, d, a; receive result)
    ├── rs232.cpp               # C++ equivalent
    ├── key.bin / enc.bin       # Test vectors
    └── golden/                 # Reference decode outputs and Python RSA reference
        ├── rsa.py              # Pure-Python RSA for golden comparison
        ├── key.bin / enc*.bin  # Additional test cases
        └── dec*.txt            # Expected plaintext outputs
```

---

## Build & Test

### Quartus + Qsys

1. Build the Qsys system (see lab slides): add the RS-232 Intel IP and connect it to the Avalon bus; add `Rsa256Wrapper` as a custom Avalon master.
2. Open the Quartus project (`.qpf` / `.qsf`), compile, and program the board.
3. Connect PC to DE2-115 via RS-232 cable.

### VCS simulation

```bash
# Test Rsa256Core only
vcs src/tb_verilog/tb.sv src/Rsa256Core.sv \
    -full64 -R -debug_access+all -sverilog +access+rw

# Test Rsa256Wrapper (argument order matters)
vcs src/tb_verilog/test_wrapper.sv src/tb_verilog/PipelineCtrl.v \
    src/tb_verilog/PipelineTb.v \
    src/Rsa256Wrapper.sv src/Rsa256Core.sv \
    -full64 -R -debug_access+all -sverilog +access+rw
```

### Host script

```bash
# Python 2 / 3
python src/pc_python/rs232.py /dev/tty.usbserial-XXXX
# Windows: python rs232.py COM3
```

Decrypts `enc.bin` using the private key in `key.bin` and prints the plaintext.

### Golden reference

```bash
python src/pc_python/golden/rsa.py d < enc.bin > plain.txt
diff plain.txt src/pc_python/golden/dec1.txt
```
