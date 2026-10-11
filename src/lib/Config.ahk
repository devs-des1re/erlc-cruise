; ---------------------------------------------------------------------------
; Config.ahk - persistent settings stored in %APPDATA%\ERLCCruise\config.ini.
; Missing keys are written back with their defaults on first load.
;
; The tuning defaults are ported from the prototype's settings block so first
; run behaves the same as the original script.
; ---------------------------------------------------------------------------

class Config {
    static Ini := Paths.ConfigFile

    static Defaults := Map(
        "General", Map(
            "StartTarget", 40,
            "Increment", 5,
            "UpdateInterval", 100,
            "LockCurrentSpeedOnToggle", 0
        ),
        "Hotkeys", Map(
            "Region", "F5",
            "Toggle", "F6",
            "IncrementUp", "F7",
            "IncrementDown", "F8",
            "Debug", "F9",
            "Cancel", "~s",
            "Settings", "F10",
            "ToggleHud", "F11"
        ),
        "Controller", Map(
            "PwmPeriod", 300,
            "Kp", "0.08",
            "Ki", "0.02",
            "Kd", "0.05",
            "FullThrottleGap", 10,
            "BrakeSoftGap", 4,
            "BrakeHardGap", 8,
            "BrakeAccelThreshold", "2.0",
            "BrakeReleaseGap", "1.5",
            "BrakeLookahead", "0.6",
            "MinBrakeHold", 500,
            "MinBrakeSpeed", 8
        ),
        "Hud", Map(
            "X", 20,
            "Y", 20,
            "Width", 324,
            "Opacity", 225,
            "Visible", 1
        ),
        "Region", Map(
            "X", 0,
            "Y", 0,
            "W", 0,
            "H", 0
        ),
        "Ocr", Map(
            "Language", "en-us",
            "Scale", 3,
            "Grayscale", 0,
            "InvertColors", 0,
            "Monochrome", 0
        ),
        "Settings", Map(
            "Logging", 1,
            "OnlyWhenFocused", 1,
            "GameProcess", "RobloxPlayerBeta.exe"
        ),
        "Version", Map(
            "Config", 1
        )
    )

    ; Ensures every default key exists in the ini file.
    static Load() {
        sentinel := "`u{1F5FF}__missing__`u{1F5FF}"
        for section, keys in this.Defaults {
            for key, def in keys {
                if (IniRead(this.Ini, section, key, sentinel) = sentinel)
                    IniWrite(def, this.Ini, section, key)
            }
        }
    }

    static Get(section, key, defaultVal := "") {
        def := (this.Defaults.Has(section) && this.Defaults[section].Has(key))
            ? this.Defaults[section][key] : defaultVal
        return IniRead(this.Ini, section, key, def)
    }

    static Set(section, key, value) {
        IniWrite(value, this.Ini, section, key)
    }

    static GetInt(section, key) {
        return this.Get(section, key, "0") + 0
    }

    static GetFloat(section, key) {
        return this.Get(section, key, "0") + 0.0
    }

    static GetBool(section, key) {
        v := this.Get(section, key, "0")
        return (v = "1" || v = "true" || v = "yes")
    }

    ; --- region helpers -----------------------------------------------------

    static GetRegion() {
        return {
            X: this.GetInt("Region", "X"),
            Y: this.GetInt("Region", "Y"),
            W: this.GetInt("Region", "W"),
            H: this.GetInt("Region", "H")
        }
    }

    static SetRegion(x, y, w, h) {
        this.Set("Region", "X", x)
        this.Set("Region", "Y", y)
        this.Set("Region", "W", w)
        this.Set("Region", "H", h)
    }

    static HasRegion() {
        r := this.GetRegion()
        return r.W >= 5 && r.H >= 5
    }

    ; --- hotkey helpers -----------------------------------------------------

    static GetHotkey(name, defaultVal := "") {
        return Trim(this.Get("Hotkeys", name, defaultVal))
    }

    static SetHotkey(name, value) {
        this.Set("Hotkeys", name, Trim(value))
    }
}
