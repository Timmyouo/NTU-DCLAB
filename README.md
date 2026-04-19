# NTU Digital Circuits Lab — FPGA / Quartus Portfolio

Hands-on **FPGA system design** projects from the **Digital Circuits Lab (數位電路實驗)** course at **National Taiwan University (NTU), Fall 2025**, all built and demonstrated live on the **Terasic DE2-115 (Intel Cyclone IV E, EP4CE115F29C7)** development board.

Every project in this portfolio was **synthesized, placed & routed in Quartus II, programmed onto real hardware, and verified end-to-end using the board's actual peripherals** — external SRAM, VGA, RS-232, on-board audio codec, push-buttons, switches, seven-segment displays, and (for the capstone) a Bluetooth-linked Arduino controller. Where appropriate, **Qsys / Platform Designer** is used to compose the Avalon-MM subsystem (PLLs, RS-232 IP, custom masters) around the hand-written RTL.

> GitHub: [Timmyouo/NTU-DCLAB](https://github.com/Timmyouo/NTU-DCLAB-labs)
> Capstone (separate repo): [Timmyouo/FPGA-Dart-Game](https://github.com/Timmyouo/FPGA-Dart-Game)

---

## Projects at a Glance

| # | Topic | FPGA / Hardware Focus | Folder |
|---|-------|------------------------|--------|
| Lab 1 | FPGA Intro & LFSR Slot-Machine | First end-to-end Quartus flow on DE2-115: pin assignment, SDC constraints, `.sof` programming, seven-segment & key debouncing | [`lab01_fpga_intro/`](lab01_fpga_intro/) |
| Lab 2 | RSA-256 Hardware Accelerator | **Qsys SoC integration**: Altera PLL + on-chip RS-232 IP + a hand-written **Avalon-MM custom master**; live PC ↔ FPGA RS-232 link | [`lab02_rsa256/`](lab02_rsa256/) |
| Lab 3 | Audio Recorder / Player | **Mixed-signal peripheral bring-up** on DE2-115: WM8731 audio codec over I²C, I²S audio streaming, 1 M × 16 external SRAM as audio buffer, Qsys-generated Altpll | [`lab03_audio_i2c/`](lab03_audio_i2c/) |
| **Final** | **Two-Player FPGA Dart Game** | Full-stack FPGA system: **VGA** frame compositor over **external SRAM**, **UART / Bluetooth (HC-05)** link to an Arduino controller, Qsys PLL for VGA pixel clock | [FPGA-Dart-Game ↗](https://github.com/Timmyouo/FPGA-Dart-Game) |

---

## FPGA Skills Demonstrated

**DE2-115 peripheral bring-up on real hardware**
- **External SRAM** (IS61WV102416BLL, 1 M × 16): used as both an audio recording buffer (Lab 3) and a full-frame VGA graphics memory (Final).
- **VGA controller**: standard timing generator + per-pixel SRAM read path driving the on-board ADV7123 video DAC.
- **WM8731 audio codec** brought up from cold: I²C register programming, I²S ADC capture and DAC playback on the real codec chip.
- **RS-232 link** to a PC using the on-board MAX3232 transceiver and an Intel Avalon-MM RS-232 IP in Qsys.
- **UART over Bluetooth (HC-05)** at 115200 bps for a wireless controller link.
- **User interface peripherals**: push-buttons with debouncing, slide switches, seven-segment displays, red/green LEDs as status indicators.

**Quartus II flow, end to end**
- Top-level project assembly from `.qpf` / `.qsf`; explicit **pin assignments** for every external peripheral on the DE2-115.
- **SDC timing constraints** for the 50 MHz system clock plus derived clocks (VGA pixel clock, codec MCLK / BCLK, I²C SCLK).
- Full **synthesis → fitter → Assembler** flow targeting **EP4CE115F29C7**, producing the `.sof` programmed on the actual board.
- On-board debug using **SignalTap II**, LEDs, and seven-segment readouts as live debug taps.

**Qsys / Platform Designer (Altera SoC composition)**
- **Altera PLL (Altpll) IP**: clock synthesis for the I²C reference clock (Lab 3) and the VGA pixel clock (Final).
- **Intel RS-232 UART IP**: integrated as an Avalon-MM slave (Lab 2).
- **Custom Avalon-MM master**: `Rsa256Wrapper` exported as a bus master that actively drives the RS-232 IP's status / data registers through the Avalon interconnect (Lab 2).
- Automatic generation of the Qsys subsystem Verilog and integration into the Quartus project via `.qip`.

**RTL for FPGA, built to work on silicon**
- Hand-written FSMs and datapaths in **SystemVerilog**, targeted at Cyclone IV E LEs / M9K blocks.
- **Multi-clock-domain** design: 50 MHz system clock, VGA pixel clock, codec BCLK / LRCK, I²C SCLK, UART bit clock, all coordinated through PLLs and handshake synchronisers.
- Fixed-point arithmetic used in place of floating-point for DSP (audio speed change) and real-time physics (dart trajectory) — friendly to FPGA fabric.

---

## Hardware Platform

| Resource | Used in this portfolio |
|----------|------------------------|
| Cyclone IV E **EP4CE115F29C7** FPGA | Logic, M9K block RAM, PLL |
| 50 MHz on-board oscillator | System clock for every project |
| **1 M × 16** asynchronous SRAM | Audio buffer (Lab 3), VGA frame & asset store (Final) |
| **WM8731** audio codec (I²C + I²S) | Record / playback (Lab 3) |
| **VGA** output (ADV7123 DAC) | Game UI, dartboard, HUD (Final) |
| **RS-232** transceiver | PC ↔ FPGA operand / result link (Lab 2) |
| HC-05 Bluetooth module (external) | Wireless controller link (Final) |
| MPU6050 IMU + joystick + Arduino | Motion-capture controller (Final) |
| KEYs, SWs, LEDs, 7-seg | UI & on-board debug (all labs) |

## Toolchain

| Tool | Role |
|------|------|
| **Quartus II 15.0** | Synthesis, fitter, timing analyzer, Programmer (`.sof`) |
| **Qsys / Platform Designer** | Avalon-MM subsystem assembly (Altpll, RS-232 IP, custom masters) |
| **SignalTap II** | On-board logic analyzer for live hardware debug |
| **Synopsys VCS** | RTL simulation where needed |
| **Arduino IDE** | HC-05 controller firmware (Final) |
| **Python + pyserial** | Host-side test driver (Lab 2) and offline asset pipeline (Final) |

---

## Repository Layout

```
dclab-labs/
├── lab01_fpga_intro/   # First end-to-end Quartus flow on DE2-115 (LFSR slot-machine)
├── lab02_rsa256/       # Qsys SoC: Avalon-MM RSA master + RS-232 IP
└── lab03_audio_i2c/    # WM8731 codec bring-up + external SRAM audio buffer
```

Each lab folder contains its own `README.md`, `src/`, the team report PDF (`team*_lab*_report.pdf`), and the Quartus / Qsys project files (`.qpf`, `.qsf`, `.sdc`, `.qsys`, `.qip`).
