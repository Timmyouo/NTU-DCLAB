# NTU-DCLAB-labs

Lab assignments from a **digital circuits / FPGA** course at NTU, implemented in **SystemVerilog** on the **Terasic DE2-115 (Cyclone IV E)** development board.

> GitHub: [Timmyouo/NTU-DCLAB-labs](https://github.com/Timmyouo/NTU-DCLAB-labs)  
> Capstone project: [Timmyouo/FPGA-Dart-Game](https://github.com/Timmyouo/FPGA-Dart-Game)

---

## Labs

| # | Directory | Topic | Key techniques |
|---|-----------|-------|----------------|
| 1 | [`lab01_fpga_intro/`](lab01_fpga_intro/) | FPGA Intro & LFSR Random Number | Synthesizable SV style, FSM, LFSR, seven-segment display |
| 2 | [`lab02_rsa256/`](lab02_rsa256/) | RSA-256 Hardware Accelerator | Montgomery multiplication, Avalon-MM master, RS-232 host interface |
| 3 | [`lab03_audio_i2c/`](lab03_audio_i2c/) | Audio Record / Playback over I²C | I²C init, WM8731 codec, SRAM audio buffer, variable-speed DSP |

---

## Toolchain

| Tool | Purpose |
|------|---------|
| Quartus II 15.0 | Synthesis, place & route, FPGA programming |
| Qsys (Platform Designer) | SoC integration for Avalon bus (Lab 2) |
| Synopsys VCS | RTL simulation where testbenches are provided |
| Python 2/3 + pyserial | Host-side test scripts (Lab 2) |

Board: **EP4CE115F29C7** on DE2-115, 50 MHz on-board oscillator.

---

## Common coding conventions

All modules follow the course-wide **`_r` / `_w` register naming discipline**:

```systemverilog
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) reg_r <= '0;
    else          reg_r <= reg_w;   // reg_w is NEVER driven here
end

always_comb begin
    reg_w = reg_r;                  // default hold
    // ... override based on state
end
```

`_r` signals are registers (left-hand side of `always_ff` only).  
`_w` signals are combinational next-state wires (left-hand side of `always_comb` only).

---

## License

Course work — verify your institution's academic integrity policy before making this repository public.
