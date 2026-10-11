; ---------------------------------------------------------------------------
; Hud.ahk - the always-on-top status overlay (WebView2).
;
; Renders the HUD with real HTML/CSS (ui\hud.html + hud.css) so it matches the
; settings window exactly: black surface, Outfit font, rounded corners, and
; smooth rounded throttle/brake bars. Position, width, opacity, visible,
; click-through, and which fields are shown all come from Config.
;
; The overlay is drag-movable via CSS (-webkit-app-region: drag). The new
; position is detected and saved back to Config.
; ---------------------------------------------------------------------------

class Hud {
    Gui := ""
    Visible := false
    ClickThrough := false
    Width := 300
    Ready := false

    __New() {
        this.Build()
        this.ApplyConfig(false)  ; position it but stay hidden until shown
    }

    Build() {
        ; Destroy any previous overlay (e.g. when rebuilding for a click-through change).
        if (this.Gui != "" && this.Gui.Hwnd) {
            try this.Gui.Destroy()
        }

        this.ClickThrough := Config.GetBool("Hud", "ClickThrough")
        this.Width := Max(200, Config.GetInt("Hud", "Width"))

        opt := "+AlwaysOnTop -Caption -Resize +ToolWindow"
        if this.ClickThrough
            opt .= " +E0x20"        ; WS_EX_TRANSPARENT

        settings := { DataDir: Paths.WebViewHudDataDir, DefaultWidth: this.Width, DefaultHeight: 240 }
        if (A_IsCompiled) {
            WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
            settings.DllPath := WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
        } else {
            settings.DllPath := Paths.LoaderFile
        }

        g := WebViewGui(opt, "ERLC Cruise Control HUD",, settings)
        this.Gui := g
        this.Ready := false

        g.DefaultBackgroundColor := "0A0A0A"

        ; Register before navigating so the load event is never missed.
        g.NavigationCompleted((*) => this.OnReady())
        ; The page reports its content height so the window fits exactly.
        g.AddCallbackToScript("Resize", (wv, height) => this.OnResize(height))

        if !A_IsCompiled
            g.BrowseFolder(Paths.UiDir)
        g.Navigate("hud.html")

        g.OnEvent("Close", (*) => this.Hide())
    }

    ; Called once the HUD page has loaded.
    OnReady() {
        this.Ready := true
        this.PushConfig()
        ; Persist the position whenever the user drags the overlay.
        if !this.HasOwnProp("WatchFn") {
            this.WatchFn := this.WatchPosition.Bind(this)
            SetTimer(this.WatchFn, 250)
        }
    }

    ; The page reports its rendered content height; resize the window to fit.
    OnResize(height) {
        if (this.Gui = "" || !this.Gui.Hwnd)
            return
        h := Max(80, height + 0)
        x := Config.GetInt("Hud", "X")
        y := Config.GetInt("Hud", "Y")
        try this.Gui.Move(x, y, this.Width, h)
    }

    ; Detects drag repositioning (WebView2 drags the window natively) and saves it.
    WatchPosition() {
        if !this.Visible || (this.Gui = "" || !this.Gui.Hwnd)
            return
        try {
            WinGetPos(&x, &y, , , "ahk_id " this.Gui.Hwnd)
        } catch {
            return
        }
        if (x != Config.GetInt("Hud", "X") || y != Config.GetInt("Hud", "Y")) {
            Config.Set("Hud", "X", x)
            Config.Set("Hud", "Y", y)
            Logger.Action(Format("HUD moved to {1},{2}.", x, y))
        }
    }

    Show() {
        if (this.Gui = "" || !this.Gui.Hwnd)
            this.Build()
        x := Config.GetInt("Hud", "X")
        y := Config.GetInt("Hud", "Y")
        this.Gui.Show(Format("x{} y{} w{} NoActivate", x, y, this.Width))
        this.Gui.Opt("+LastFound")
        try WinSetTransparent(Config.GetInt("Hud", "Opacity"), this.Gui.Hwnd)
        this.Visible := true
        this.PushConfig()
    }

    Hide() {
        try this.Gui.Hide()
        this.Visible := false
    }

    ; Applies position, width, opacity, visibility, click-through, and field
    ; visibility from Config. Rebuilds when the click-through style changed
    ; (WS_EX_TRANSPARENT cannot be toggled on a live window).
    ApplyConfig(showHud := true) {
        if (Config.GetBool("Hud", "ClickThrough") != this.ClickThrough)
            this.Build()

        this.Width := Max(200, Config.GetInt("Hud", "Width"))
        if (this.Gui != "" && this.Gui.Hwnd) {
            this.Gui.Move(Config.GetInt("Hud", "X"), Config.GetInt("Hud", "Y"), this.Width)
            if (this.Visible)
                try WinSetTransparent(Config.GetInt("Hud", "Opacity"), this.Gui.Hwnd)
        }

        if (showHud && Config.GetBool("Hud", "Visible"))
            this.Show()
        else
            this.Hide()

        this.PushConfig()
    }

    SetOpacity(value) {
        value := Min(255, Max(30, value))
        Config.Set("Hud", "Opacity", value)
        if (this.Gui != "" && this.Gui.Hwnd) {
            this.Gui.Opt("+LastFound")
            try WinSetTransparent(value, this.Gui.Hwnd)
        }
    }

    SetVisible(visible) {
        if visible
            this.Show()
        else
            this.Hide()
        Config.Set("Hud", "Visible", visible ? 1 : 0)
    }

    ToggleVisible() {
        this.SetVisible(!this.Visible)
        Logger.Action("HUD " (this.Visible ? "shown" : "hidden") ".")
    }

    SetClickThrough(on) {
        Config.Set("Hud", "ClickThrough", on ? 1 : 0)
        this.ApplyConfig()
        Logger.Action("HUD click-through " (on ? "on" : "off") ".")
    }

    SetPosition(x, y) {
        if (this.Gui != "" && this.Gui.Hwnd)
            this.Gui.Move(x, y)
        Config.Set("Hud", "X", x)
        Config.Set("Hud", "Y", y)
    }

    ; --- rendering ----------------------------------------------------------

    ; Pushes the engine's status snapshot to the page.
    Update(engine) {
        if (!this.Ready || this.Gui = "" || !this.Gui.Hwnd)
            return
        st := engine.Status
        payload := JSON.stringify({type: "state", state: {
            active: st.active,
            debug: st.debug,
            target: st.target,
            speed: st.speed,
            accel: st.accel,
            duty: st.duty,
            brakeDuty: st.brakeDuty,
            action: st.action
        }})
        try this.Gui.PostWebMessageAsJson(payload)
    }

    ; Pushes which fields should be visible (from Config).
    PushConfig() {
        if (!this.Ready || this.Gui = "" || !this.Gui.Hwnd)
            return
        fields := {
            ShowTarget: Config.GetBool("Hud", "ShowTarget"),
            ShowSpeed: Config.GetBool("Hud", "ShowSpeed"),
            ShowThrottle: Config.GetBool("Hud", "ShowThrottle"),
            ShowBrake: Config.GetBool("Hud", "ShowBrake"),
            ShowAccel: Config.GetBool("Hud", "ShowAccel"),
            ShowAction: Config.GetBool("Hud", "ShowAction")
        }
        payload := JSON.stringify({type: "config", fields: fields})
        try this.Gui.PostWebMessageAsJson(payload)
    }
}
