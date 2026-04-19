# Lab 2 — RSA256 + Avalon + RS-232

**Goal:** Implement a **256-bit RSA** decrypt core (modular exponentiation) with a **valid/ready**-style interface, wrap it as an **Avalon-MM master** that talks to an **RS-232** UART module in a Qsys system, and verify with testbenches and host scripts.

**Contents:**

- `src/Rsa256Core.sv` — core arithmetic datapath  
- `src/Rsa256Wrapper.sv` — bus master / protocol  
- `src/tb_verilog/` — core and wrapper testbenches  
- `src/pc_python/` — host-side serial helper and reference binaries  

**Tools:** Quartus + Qsys; Python 2/3 + `pyserial` on the PC (see scripts for usage).

Diagrams (`*.drawio`, `*.xml`) are design notes from development.
