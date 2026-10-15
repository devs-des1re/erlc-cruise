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
- Per-vehicle profiles: save named tuning presets and switch between them.
- Configuration and logs saved to `%APPDATA%\ERLCCruise`.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (to run the script directly)

## Running

1. Install AutoHotkey v2.
2. Run `src/ERLCCruise.ahk`. The settings window and the HUD both open on
   launch.
3. On first run, pick a region over your speedometer using the region selector.
4. Press the toggle hotkey (default `F6`) to enable cruise.

The app lives in the system tray. Its menu has three items: **Open GUI**,
**Toggle HUD**, and **Quit**. Closing the settings window (or the HUD) hides it
to the tray and the app keeps running; left-click the tray icon to bring the
settings window back.

Hotkeys only fire while the game window is focused, so typing anywhere else
never triggers a capture.

## HUD

- Rendered with the same HTML/CSS engine and palette as the settings window, so
  it matches exactly: dark surface, Outfit font, rounded corners, and smooth
  rounded throttle/brake bars.
- Shows target, speed, throttle, brake, acceleration, and the current action.
- Drag it anywhere on screen (when click-through is off); the position is saved.
- Every field can be toggled on or off in the **HUD** tab, and its width,
  opacity, and click-through can be set there too.

## Vehicle profiles

Different cars handle differently, so tuning can be saved as named profiles and
switched between. Each profile stores the full tuning set (controller, general,
OCR, and HUD values); the speed region stays global since it depends on your
screen, not the car.

Open the **Tuning** tab to:

- **Load** a profile into the app (it becomes the active vehicle).
- **Save** the current values into the active profile.
- **New / Rename / Delete** profiles. At least one profile always remains.

Profiles live in `%APPDATA%\ERLCCruise\profiles.ini`, separate from
`config.ini`. The active profile's tuning is loaded on startup, and edits made
in the settings window are written back to it on Save. The controller's learned
hold-throttle is also remembered per profile.

## License

MIT. See [LICENSE](./LICENSE).
