# ERLC Cruise Control

A lightweight AutoHotkey v2 desktop tool that reads your speed from the screen
using offline OCR and holds it automatically, acting as an in-game cruise
control for ERLC.

> ERLC Cruise Control is an independent tool and is not affiliated with,
> endorsed by, or associated with ERLC or Roblox Corporation.

## Features

- Offline OCR of a user-selected speedometer region (no cloud calls).
- PID-style controller that pulses throttle and brakes to hold a target speed.
- Always-on-top HUD showing target, speed, throttle, brake, and acceleration.
- Snipping-tool style region selection with a live preview of what OCR reads.
- Fully configurable hotkeys, HUD position/opacity, speed increment, and tuning.
- Configuration and logs saved to `%APPDATA%\ERLCCruise`.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (to run the script directly)

## Running

1. Install AutoHotkey v2.
2. Run `src/ERLCCruise.ahk`.
3. On first run, pick a region over your speedometer using the region selector.

Hotkeys only fire while the game window is focused, so typing anywhere else
never triggers a capture.

## License

MIT. See [LICENSE](./LICENSE).
