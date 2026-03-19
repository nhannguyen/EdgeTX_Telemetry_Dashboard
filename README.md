# EdgeTX Telemetry Dashboard (800×480 and 480×320)

Two separate EdgeTX Lua widget dashboards:

- **dashboard-800x480** – For TX16S Mk3 (800×480). Includes stick monitor, full telemetry grid, context row, timers, footer.
- **dashboard-480x320** – For TX15 (480×320). Same telemetry, no stick monitor; compact layout with truncated text.

Reference (read-only): `edgetx-telemetry-dashboard-master/` – do not modify.

## Telemetry shown

- Link quality (LQ), Tx power, 1RSS / 2RSS  
- Quad battery voltage, current, mAh consumed, remaining mAh (when available)  
- Quad GPS sat count and coordinates; radio (pilot) GPS when available  
- RSNR/SNR, packet rate, flight mode  
- Arm state (ARMED / DISARMED / PREARMED)  
- Antenna mode from ELRS device name (Single 2.4, Single 900, Diversity 2.4, Diversity 900, Gemini Xrossband)  
- Temperatures (FC, ESC, VTX, motors when exposed by the model)  
- Quad power-on timer; flight time until next disarm  
- Top bar: quad name (from telemetry or model name), TX battery, time, link status  

When the link is lost, the last received values are kept and a “LINK LOST” indicator is shown. Critical-value audio uses `playFile("lowbatt.wav")` with hysteresis when supported.

## Installation

1. Copy the contents of **dashboard-800x480/** or **dashboard-480x320/** to your radio SD card so that the widget lives under `SCRIPTS/WIDGETS/DASH800/` or `SCRIPTS/WIDGETS/DASH480/` respectively.
2. Add the widget to a full-screen telemetry view (800×480 or 480×320 as appropriate).

No GAlt or cell count; icons are optional (see `icons/README.txt` in each widget).
