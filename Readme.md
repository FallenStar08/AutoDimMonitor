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
3. Place `autoDimMonitor.ahk` and `config.ini` in the same folder.
4. Edit `config.ini` with your specific path, monitor ID, and preferred brightness levels.
5. Run `autoDimMonitor.ahk`.

## Configuration (`config.ini`)

```ini
[Settings]
TargetID=\\.\DISPLAY3\Monitor0
PathToControl=C:\Path\To\controlmymonitor.exe
DimBrightness=5
BrightBrightness=80
Debug=0
Blacklist=NVIDIA Container,Overwolf
```
