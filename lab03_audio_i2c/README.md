# Lab 3 — Audio (WM8731) over I²C

**Goal:** Use **I²C** to configure the **WM8731** codec on DE2-115, then implement **record and playback** with variable speed (course requirements included interpolation modes).

**Contents:** `I2cInitializer.sv`, `AudRecorder.sv`, `AudPlayer.sv`, `AudDSP.sv`, top-level `Top.sv`, DE2-115 support files, and PLL/Qsys collateral under `Altpll*`.

**Tools:** Quartus; audio verified on hardware (simulation is limited for real audio paths).
