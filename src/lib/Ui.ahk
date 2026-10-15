; ---------------------------------------------------------------------------
; Ui.ahk - the WebView2 (HTML) settings window.
;
; Hosts ui\index.html in a native window. JS calls back into AHK through
; callbacks registered with AddCallbackToScript; AHK pushes status/state to the
; page with PostWebMessageAsJson. Closing the window hides it to the tray.
; ---------------------------------------------------------------------------

class Ui {
    static Window := ""

    static Open() {
        if (this.Window != "") {
            try {
                this.Window.Show()
                this.PushState()
                return
            } catch {
                this.Window := ""
            }
        }
        this.Build()
    }

    static Build() {
        settings := { DataDir: Paths.WebViewDataDir }
        if (A_IsCompiled) {
            WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
            settings.DllPath := WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
        } else {
            settings.DllPath := Paths.LoaderFile
        }

        g := WebViewGui("+Resize -MaximizeBox -Caption", "ERLC Cruise Control",, settings)
        this.Window := g

        g.AddCallbackToScript("GetState", (*) => this.GetStateJson())
        g.AddCallbackToScript("Save", (wv, payload) => this.OnSave(payload))
        g.AddCallbackToScript("ResetDefaults", (*) => this.OnReset())
        g.AddCallbackToScript("OpenDataFolder", (*) => (Run(Paths.AppDataDir), "Opened."))
        g.AddCallbackToScript("OpenLogs", (*) => (Run(Paths.LogsDir), "Opened."))
        g.AddCallbackToScript("SelectRegion", (*) => this.OnSelectRegion())
        g.AddCallbackToScript("TestRead", (*) => this.OnTestRead())
        g.AddCallbackToScript("ProfileApply", (wv, name) => this.OnProfileApply(String(name)))
        g.AddCallbackToScript("ProfileSave", (wv, name) => this.OnProfileSave(String(name)))
        g.AddCallbackToScript("ProfileCreate", (wv, name) => this.OnProfileCreate(String(name)))
        g.AddCallbackToScript("ProfileRename", (wv, payload) => this.OnProfileRename(String(payload)))
        g.AddCallbackToScript("ProfileDelete", (wv, name) => this.OnProfileDelete(String(name)))
        g.AddCallbackToScript("CloseWindow", (*) => (this.Hide(), ""))

        g.OnEvent("Close", (*) => this.Hide())

        if !A_IsCompiled
            g.BrowseFolder(Paths.UiDir)
        g.Navigate("index.html")

        g.Show("w820 h580")
        this.SetWindowIcon(g)
    }

    static SetWindowIcon(g) {
        if (Paths.IconFile = "" || !FileExist(Paths.IconFile))
            return
        hSmall := DllCall("LoadImage", "ptr", 0, "str", Paths.IconFile, "uint", 1, "int", 16, "int", 16, "uint", 0x10, "ptr")
        hBig := DllCall("LoadImage", "ptr", 0, "str", Paths.IconFile, "uint", 1, "int", 32, "int", 32, "uint", 0x10, "ptr")
        if hSmall
            SendMessage(0x80, 0, hSmall, , "ahk_id " g.Hwnd)
        if hBig
            SendMessage(0x80, 1, hBig, , "ahk_id " g.Hwnd)
    }

    static Hide() {
        try
            this.Window.Hide()
        TrayTip("ERLC Cruise Control is still running. Left-click the tray icon to reopen.", "Minimized to tray", 0x1)
    }

    static Exists() {
        return this.Window != ""
    }

    ; --- bridge -------------------------------------------------------------

    static GetStateJson() {
        return JSON.stringify(this.BuildState())
    }

    static BuildState() {
        r := Config.GetRegion()
        return {
            general: {
                startTarget: Min(Config.MaxTargetSpeed, Max(0, Config.GetInt("General", "StartTarget"))),
                increment: Config.GetInt("General", "Increment"),
                updateInterval: Config.GetInt("General", "UpdateInterval"),
                lockOnToggle: Config.GetBool("General", "LockCurrentSpeedOnToggle")
            },
            settings: {
                logging: Config.GetBool("Settings", "Logging"),
                gameProcess: Config.Get("Settings", "GameProcess")
            },
            hotkeys: {
                Region: Config.GetHotkey("Region"),
                Toggle: Config.GetHotkey("Toggle"),
                IncrementUp: Config.GetHotkey("IncrementUp"),
                IncrementDown: Config.GetHotkey("IncrementDown"),
                Debug: Config.GetHotkey("Debug"),
                Cancel: Config.GetHotkey("Cancel"),
                CancelAccelerate: Config.GetHotkey("CancelAccelerate"),
                Settings: Config.GetHotkey("Settings"),
                ToggleHud: Config.GetHotkey("ToggleHud")
            },
            controller: {
                PwmPeriod: Config.GetInt("Controller", "PwmPeriod"),
                Kp: Config.GetFloat("Controller", "Kp"),
                Ki: Config.GetFloat("Controller", "Ki"),
                Kd: Config.GetFloat("Controller", "Kd"),
                FullThrottleGap: Config.GetInt("Controller", "FullThrottleGap"),
                BrakeSoftGap: Config.GetInt("Controller", "BrakeSoftGap"),
                BrakeHardGap: Config.GetInt("Controller", "BrakeHardGap"),
                BrakeAccelThreshold: Config.GetFloat("Controller", "BrakeAccelThreshold"),
                BrakeReleaseGap: Config.GetFloat("Controller", "BrakeReleaseGap"),
                BrakeLookahead: Config.GetFloat("Controller", "BrakeLookahead"),
                MinBrakeHold: Config.GetInt("Controller", "MinBrakeHold"),
                MinBrakeSpeed: Config.GetInt("Controller", "MinBrakeSpeed")
            },
            hud: {
                X: Config.GetInt("Hud", "X"),
                Y: Config.GetInt("Hud", "Y"),
                Width: Config.GetInt("Hud", "Width"),
                Opacity: Config.GetInt("Hud", "Opacity"),
                Visible: Config.GetBool("Hud", "Visible"),
                ClickThrough: Config.GetBool("Hud", "ClickThrough"),
                ShowTarget: Config.GetBool("Hud", "ShowTarget"),
                ShowSpeed: Config.GetBool("Hud", "ShowSpeed"),
                ShowThrottle: Config.GetBool("Hud", "ShowThrottle"),
                ShowBrake: Config.GetBool("Hud", "ShowBrake"),
                ShowAccel: Config.GetBool("Hud", "ShowAccel"),
                ShowAction: Config.GetBool("Hud", "ShowAction")
            },
            ocr: {
                Language: Config.Get("Ocr", "Language"),
                Scale: Config.GetInt("Ocr", "Scale"),
                Grayscale: Config.GetBool("Ocr", "Grayscale"),
                InvertColors: Config.GetBool("Ocr", "InvertColors"),
                Monochrome: Config.GetInt("Ocr", "Monochrome")
            },
            region: {x: r.X, y: r.Y, w: r.W, h: r.H, set: Config.HasRegion()},
            profiles: {list: Profiles.List(), active: Profiles.Active()},
            debug: this.BuildDebug()
        }
    }

    static BuildDebug() {
        return {
            version: AppVersion,
            os: this.OsVersion(),
            ahk: A_AhkVersion,
            webview2: this.WebView2Version(),
            game: GameWindow.Exists() ? "running" : "not found",
            region: Config.HasRegion() ? "set" : "not set",
            logging: Config.GetBool("Settings", "Logging") ? "on" : "off",
            dataDir: Paths.AppDataDir
        }
    }

    static OsVersion() {
        try {
            v := RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "ProductName")
            build := RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentBuildNumber")
            return v " (build " build ")"
        } catch {
            return "Windows"
        }
    }

    static WebView2Version() {
        for key in ["HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
                  , "HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
                  , "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"] {
            try {
                v := RegRead(key, "pv")
                if (v != "")
                    return v
            }
        }
        return "unknown"
    }

    static OnSave(jsonText) {
        try {
            state := JSON.parse(jsonText, false, false)

            ; General
            Config.Set("General", "StartTarget", Min(Config.MaxTargetSpeed, Max(0, this.ToInt(state.general.startTarget, 40))))
            Config.Set("General", "Increment", this.ToInt(state.general.increment, 5))
            Config.Set("General", "UpdateInterval", this.ToInt(state.general.updateInterval, 100))
            Config.Set("General", "LockCurrentSpeedOnToggle", state.general.lockOnToggle ? 1 : 0)

            ; Settings
            Config.Set("Settings", "Logging", state.settings.logging ? 1 : 0)
            gp := Trim(state.settings.gameProcess)
            Config.Set("Settings", "GameProcess", gp != "" ? gp : "RobloxPlayerBeta.exe")

            ; Hotkeys
            hk := state.hotkeys
            Config.SetHotkey("Region", this.CleanHotkey(hk.Region))
            Config.SetHotkey("Toggle", this.CleanHotkey(hk.Toggle))
            Config.SetHotkey("IncrementUp", this.CleanHotkey(hk.IncrementUp))
            Config.SetHotkey("IncrementDown", this.CleanHotkey(hk.IncrementDown))
            Config.SetHotkey("Debug", this.CleanHotkey(hk.Debug))
            Config.SetHotkey("Cancel", this.CleanHotkey(hk.Cancel))
            Config.SetHotkey("CancelAccelerate", this.CleanHotkey(hk.CancelAccelerate))
            Config.SetHotkey("Settings", this.CleanHotkey(hk.Settings))
            Config.SetHotkey("ToggleHud", this.CleanHotkey(hk.ToggleHud))

            ; Controller
            ctrl := state.controller
            Config.Set("Controller", "PwmPeriod", this.CleanNumber(ctrl.PwmPeriod))
            Config.Set("Controller", "Kp", this.CleanNumber(ctrl.Kp))
            Config.Set("Controller", "Ki", this.CleanNumber(ctrl.Ki))
            Config.Set("Controller", "Kd", this.CleanNumber(ctrl.Kd))
            Config.Set("Controller", "FullThrottleGap", this.CleanNumber(ctrl.FullThrottleGap))
            Config.Set("Controller", "BrakeSoftGap", this.CleanNumber(ctrl.BrakeSoftGap))
            Config.Set("Controller", "BrakeHardGap", this.CleanNumber(ctrl.BrakeHardGap))
            Config.Set("Controller", "BrakeAccelThreshold", this.CleanNumber(ctrl.BrakeAccelThreshold))
            Config.Set("Controller", "BrakeReleaseGap", this.CleanNumber(ctrl.BrakeReleaseGap))
            Config.Set("Controller", "BrakeLookahead", this.CleanNumber(ctrl.BrakeLookahead))
            Config.Set("Controller", "MinBrakeHold", this.CleanNumber(ctrl.MinBrakeHold))
            Config.Set("Controller", "MinBrakeSpeed", this.CleanNumber(ctrl.MinBrakeSpeed))

            ; HUD
            Config.Set("Hud", "X", this.ToInt(state.hud.X, 20))
            Config.Set("Hud", "Y", this.ToInt(state.hud.Y, 20))
            Config.Set("Hud", "Width", Max(200, this.ToInt(state.hud.Width, 300)))
            Config.Set("Hud", "Opacity", Min(255, Max(30, this.ToInt(state.hud.Opacity, 235))))
            Config.Set("Hud", "Visible", state.hud.Visible ? 1 : 0)
            Config.Set("Hud", "ClickThrough", state.hud.ClickThrough ? 1 : 0)
            Config.Set("Hud", "ShowTarget", state.hud.ShowTarget ? 1 : 0)
            Config.Set("Hud", "ShowSpeed", state.hud.ShowSpeed ? 1 : 0)
            Config.Set("Hud", "ShowThrottle", state.hud.ShowThrottle ? 1 : 0)
            Config.Set("Hud", "ShowBrake", state.hud.ShowBrake ? 1 : 0)
            Config.Set("Hud", "ShowAccel", state.hud.ShowAccel ? 1 : 0)
            Config.Set("Hud", "ShowAction", state.hud.ShowAction ? 1 : 0)

            ; OCR
            Config.Set("Ocr", "Language", Trim(state.ocr.Language) != "" ? Trim(state.ocr.Language) : "en-us")
            Config.Set("Ocr", "Scale", Max(1, this.ToInt(state.ocr.Scale, 3)))
            Config.Set("Ocr", "Grayscale", state.ocr.Grayscale ? 1 : 0)
            Config.Set("Ocr", "InvertColors", state.ocr.InvertColors ? 1 : 0)
            Config.Set("Ocr", "Monochrome", Min(255, Max(0, this.ToInt(state.ocr.Monochrome, 0))))

            ; Apply live
            Logger.Enabled := Config.GetBool("Settings", "Logging")
            Logger.Info("Settings saved from UI.")
            this.ApplyLive()
            ; Keep the active vehicle profile in step with the edited values.
            active := Profiles.Active()
            if (active != "")
                Profiles.Save(active)

            this.PushState()
            this.PushStatus("Saved.", "ok")
            return "Saved."
        } catch as e {
            Logger.Exception(e, "Ui.OnSave")
            this.PushStatus("Save failed: " e.Message, "err")
            return "Save failed."
        }
    }

    ; Re-applies everything that reads from Config after a change.
    static ApplyLive() {
        Logger.Enabled := Config.GetBool("Settings", "Logging")
        Hotkeys.Register()
        gEngine.Reload()
        gHud.ApplyConfig()
    }

    static OnReset() {
        for section, keys in Config.Defaults
            for key, def in keys
                Config.Set(section, key, def)
        this.ApplyLive()
        ; Mirror the reset into the active profile so it does not drift.
        active := Profiles.Active()
        if (active != "")
            Profiles.Save(active)
        this.PushState()
        this.PushStatus("Defaults restored.", "ok")
        return this.GetStateJson()
    }

    static OnSelectRegion() {
        this.Hide()
        if RegionSelector.PickAndSave() {
            gEngine.BuildStatus()
            this.PushState()
            this.PushStatus("Region saved.", "ok")
        } else {
            this.PushStatus("Region selection cancelled.", "")
        }
        this.Open()
        return "done"
    }

    static OnTestRead() {
        read := gEngine.Reader.ReadOnce()
        if (read.Speed < 0) {
            this.PushStatus("Read failed: " read.Raw, "err")
            return "failed"
        }
        this.PushStatus(Format("Read {1} (raw '{2}').", read.Speed, read.Raw), "ok")
        return "ok"
    }

    ; --- vehicle profiles ---------------------------------------------------
    ; Each handler mutates the store, re-applies live, and returns the fresh
    ; state JSON so the page can re-render from a single round trip.

    static OnProfileApply(name) {
        if !Profiles.Apply(name) {
            this.PushStatus("Profile not found: " name, "err")
            return this.GetStateJson()
        }
        Profiles.SetActive(name)
        this.ApplyLive()
        this.PushStatus("Applied profile " name ".", "ok")
        return this.GetStateJson()
    }

    static OnProfileSave(name) {
        if !Profiles.Save(name) {
            this.PushStatus("Could not save profile " name ".", "err")
            return this.GetStateJson()
        }
        ; Saving to a profile also makes it the one in use.
        Profiles.SetActive(name)
        this.PushStatus("Saved profile " name ".", "ok")
        return this.GetStateJson()
    }

    static OnProfileCreate(name) {
        if !Profiles.Create(name) {
            this.PushStatus("Could not create profile (name empty or already exists).", "err")
            return this.GetStateJson()
        }
        this.ApplyLive()
        this.PushStatus("Created profile " Profiles.Active() ".", "ok")
        return this.GetStateJson()
    }

    ; payload is "old`nnew" so names with spaces survive the round trip.
    static OnProfileRename(payload) {
        parts := StrSplit(payload, "`n", , 2)
        old := parts.Length >= 1 ? parts[1] : ""
        new := parts.Length >= 2 ? parts[2] : ""
        if !Profiles.Rename(old, new) {
            this.PushStatus("Rename failed (name empty or already in use).", "err")
            return this.GetStateJson()
        }
        this.PushStatus("Renamed to " Profiles.Sanitize(new) ".", "ok")
        return this.GetStateJson()
    }

    static OnProfileDelete(name) {
        if !Profiles.Delete(name) {
            this.PushStatus("Cannot delete the last profile.", "err")
            return this.GetStateJson()
        }
        ; If we removed the active one, load whatever is now active.
        this.ApplyLive()
        this.PushStatus("Deleted profile " name ".", "ok")
        return this.GetStateJson()
    }

    ; --- push helpers -------------------------------------------------------

    static PushState() {
        if !this.Exists()
            return
        payload := JSON.stringify({ type: "state", state: this.BuildState() })
        try this.Window.PostWebMessageAsJson(payload)
    }

    static PushStatus(message, kind) {
        if !this.Exists()
            return
        payload := JSON.stringify({ type: "status", message: message, kind: kind })
        try this.Window.PostWebMessageAsJson(payload)
    }

    ; --- value helpers ------------------------------------------------------

    static CleanHotkey(value) {
        return (value = "" || value = "Press keys…" || value = "Not set") ? "" : Trim(value)
    }

    static ToInt(value, defaultVal) {
        v := Trim(String(value))
        if (v = "" || !IsNumber(v))
            return defaultVal
        return Integer(v)
    }

    static CleanNumber(value) {
        v := Trim(String(value))
        return (v = "" || !IsNumber(v)) ? "0" : v
    }
}
