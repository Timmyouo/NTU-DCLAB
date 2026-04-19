# NTU-DCLAB-2025-FALL

Lab assignments from a **digital circuits / FPGA** course at NTU(National Taiwan University), implemented in **SystemVerilog** on the **Terasic DE2-115 (Cyclone IV E)** development board.

> GitHub: [Timmyouo/NTU-DCLAB-labs](https://github.com/Timmyouo/NTU-DCLAB-labs)

---

## Projects


|           | Topic                                    | Key Techniques                                                  | Repo                                                           |
| --------- | ---------------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------- |
| Lab 1     | FPGA Intro & LFSR Random Number          | Synthesizable SV, FSM, LFSR, seven-segment display              | `[lab01_fpga_intro/](lab01_fpga_intro/)`                       |
| Lab 2     | RSA-256 Hardware Accelerator             | Montgomery multiplication, Avalon-MM master, RS-232             | `[lab02_rsa256/](lab02_rsa256/)`                               |
| Lab 3     | Audio Record / Playback and Speed Change | I²C init, WM8731 codec, SRAM buffer, variable-speed DSP         | `[lab03_audio_i2c/](lab03_audio_i2c/)`                         |
| **Final** | **Two-Player FPGA Dart Game**            | VGA, external SRAM, Bluetooth UART, IMU physics engine, Arduino | [FPGA-Dart-Game ↗](https://github.com/Timmyouo/FPGA-Dart-Game) |


---

## Toolchain


| Tool                     | Purpose                                       |
| ------------------------ | --------------------------------------------- |
| Quartus II 15.0          | Synthesis, place & route, FPGA programming    |
| Qsys (Platform Designer) | SoC integration for Avalon bus (Lab 2)        |
| Synopsys VCS             | RTL simulation where testbenches are provided |
| Python 2/3 + pyserial    | Host-side test scripts (Lab 2)                |


Board: **EP4CE115F29C7** on DE2-115, 50 MHz on-board oscillator.