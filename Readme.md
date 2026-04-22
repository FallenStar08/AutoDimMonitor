# AutoDimMonitor

Automates monitor brightness based on window activity.

When no windows are present on a specific screen, it dims to a preset level.

When a window is moved onto it, it restores full brightness.

## Features

- **Event-Driven:** Uses WinEventHooks (no stinky timers).
- **Portable:** Configurable via `.ini` file.
- **Lightweight:** Tiny footprint, runs in the background.
- **Blacklist:** Ignore specific windows (like overlays or system tools) that shouldn't trigger brightness.
- **Debug Mode:** On-screen overlay to see exactly which windows are being detected.

## Prerequisites

- [AutoHotkey v1.1+](https://www.autohotkey.com/)
- [ControlMyMonitor](https://www.nirsoft.net/utils/control_my_monitor.html) by NirSoft.

## Installation

1. Download `ControlMyMonitor.exe` and note its file path.
2. Run `ControlMyMonitor.exe` to find your target monitor's ID (e.g., `\\.\DISPLAY3\Monitor0`).
3. Run `autoDimMonitor.ahk`. You can also add it to your startup folder to make it run at startup.
4. Edit the config.ini file the script generated after the first run to your liking.

## Configuration (`config.ini`)

```ini
[Settings]
; Path to ControlMyMonitor executable
PathToControl={pathToControlMyMonitor}\controlmymonitor.exe

; Brightness levels (0-100)
DimBrightness=5
BrightBrightness=65
Debug=0
Blacklist=Program Manager,NVIDIA Container
; The display number to monitor (e.g. 3 for display 3)
TargetDisplayNum=3
```
