; ---------------------------------------------------------------------------
; Profiles.ahk - per-vehicle settings presets.
;
; A profile is a named snapshot of "everything that drives the car": the
; Controller tuning, General, OCR, and HUD values. Region and the global app
; settings (hotkeys, game process, logging) are deliberately not per-vehicle.
;
; Profiles live in their own %APPDATA%\ERLCCruise\profiles.ini so config.ini
; stays the single "current values" file. Applying a profile writes its values
; into Config; saving settings snapshots the active profile back, so the two
; stay in sync.
; ---------------------------------------------------------------------------

class Profiles {
    static Ini := Paths.AppDataDir "\profiles.ini"

    ; The sections and keys captured per profile. LearnedDuty is the
    ; controller's learned hold-throttle, persisted so per-car learning sticks.
    static Spec := Map(
        "General", ["StartTarget", "Increment", "UpdateInterval", "LockCurrentSpeedOnToggle"],
        "Ocr", ["Language", "Scale", "Grayscale", "InvertColors", "Monochrome"],
        "Hud", ["X", "Y", "Width", "Opacity", "Visible", "ClickThrough"
              , "ShowTarget", "ShowSpeed", "ShowThrottle", "ShowBrake", "ShowAccel", "ShowAction"],
        "Controller", ["PwmPeriod", "Kp", "Ki", "Kd", "FullThrottleGap", "BrakeSoftGap"
                     , "BrakeHardGap", "BrakeAccelThreshold", "BrakeReleaseGap", "BrakeLookahead"
                     , "MinBrakeHold", "MinBrakeSpeed", "LearnedDuty"]
    )

    ; --- lifecycle ----------------------------------------------------------

    ; Seeds a Default profile from the current settings on first run, and makes
    ; sure the stored Active name points at something that exists.
    static Ensure() {
        if (IniRead(this.Ini, "Profiles", "Names", "") = "") {
            this.WriteProfile("Default", this.Capture())
            IniWrite("Default", this.Ini, "Profiles", "Names")
            IniWrite("Default", this.Ini, "Profiles", "Active")
            return
        }
        if !this.Exists(this.Active()) {
            names := this.List()
            if names.Length
                IniWrite(names[1], this.Ini, "Profiles", "Active")
        }
    }

    ; --- queries ------------------------------------------------------------

    static List() {
        raw := IniRead(this.Ini, "Profiles", "Names", "")
        names := []
        for name in StrSplit(raw, "|")
            if (Trim(name) != "")
                names.Push(Trim(name))
        return names
    }

    static Active() {
        a := Trim(IniRead(this.Ini, "Profiles", "Active", ""))
        if (a = "") {
            names := this.List()
            return names.Length ? names[1] : ""
        }
        return a
    }

    static Exists(name) {
        for n in this.List()
            if (n = name)
                return true
        return false
    }

    ; Returns a Map of "Section.Key" -> value read from the given profile,
    ; falling back to the current Config value for any missing key.
    static Snapshot(name) {
        out := Map()
        for section, keys in this.Spec
            for key in keys
                out[section "." key] := IniRead(this.Ini, name, section "." key, Config.Get(section, key))
        return out
    }

    ; --- mutations ----------------------------------------------------------

    ; Snapshots the current Config values into the named profile.
    static Save(name) {
        if (this.Sanitize(name) = "")
            return false
        if this.Exists(name)
            try IniDelete(this.Ini, name)
        this.WriteProfile(name, this.Capture())
        return true
    }

    ; Creates a new profile seeded from the current settings and makes it active.
    static Create(name) {
        name := this.Sanitize(name)
        if (name = "" || this.Exists(name))
            return false
        this.AppendName(name)
        this.Save(name)
        this.SetActive(name)
        return true
    }

    static Rename(old, new) {
        new := this.Sanitize(new)
        if (new = "" || !this.Exists(old) || (new != old && this.Exists(new)))
            return false
        values := this.Snapshot(old)
        try IniDelete(this.Ini, old)
        this.WriteProfile(new, values)
        names := this.List()
        for i, n in names
            if (n = old)
                names[i] := new
        this.WriteNames(names)
        if (this.Active() = old)
            IniWrite(new, this.Ini, "Profiles", "Active")
        return true
    }

    ; Deletes a profile. Refuses to remove the last remaining one.
    static Delete(name) {
        if !this.Exists(name)
            return false
        remaining := []
        for n in this.List()
            if (n != name)
                remaining.Push(n)
        if (remaining.Length = 0)
            return false
        try IniDelete(this.Ini, name)
        this.WriteNames(remaining)
        if (this.Active() = name)
            IniWrite(remaining[1], this.Ini, "Profiles", "Active")
        return true
    }

    static SetActive(name) {
        if !this.Exists(name)
            return false
        IniWrite(name, this.Ini, "Profiles", "Active")
        return true
    }

    ; Applies a profile's values into Config. Returns true on success.
    static Apply(name) {
        if !this.Exists(name)
            return false
        for packed, value in this.Snapshot(name) {
            parts := StrSplit(packed, ".")
            Config.Set(parts[1], parts[2], value)
        }
        return true
    }

    ; Updates a single value inside a profile without rewriting it all.
    static SetValue(name, section, key, value) {
        if !this.Exists(name)
            return false
        IniWrite(value, this.Ini, name, section "." key)
        return true
    }

    ; --- helpers ------------------------------------------------------------

    ; Captures the current Config values for every key we track.
    static Capture() {
        out := Map()
        for section, keys in this.Spec
            for key in keys
                out[section "." key] := Config.Get(section, key)
        return out
    }

    static WriteProfile(name, values) {
        for packed, value in values
            IniWrite(value, this.Ini, name, packed)
    }

    static AppendName(name) {
        names := this.List()
        names.Push(name)
        this.WriteNames(names)
    }

    static WriteNames(names) {
        IniWrite(this.JoinNames(names), this.Ini, "Profiles", "Names")
    }

    static JoinNames(names) {
        s := ""
        for n in names
            s .= (s = "" ? "" : "|") n
        return s
    }

    ; Profiles are used as INI section names, so strip characters that would
    ; break that, collapse whitespace, and cap the length.
    static Sanitize(name) {
        name := Trim(name)
        name := RegExReplace(name, "[\[\]\|\r\n]", "")
        name := RegExReplace(name, "\s+", " ")
        return SubStr(name, 1, 32)
    }
}
