; ---------------------------------------------------------------------------
; Hud.ahk - the always-on-top status overlay.
;
; A frameless, click-through overlay showing cruise state, target, speed,
; throttle, brake, and acceleration. Position, width, opacity, and visibility
; come from Config and can be changed live.
;
; Port of the prototype's HUD, rebuilt as a class driven by a status snapshot.
; ---------------------------------------------------------------------------

class Hud {
    Gui := ""
    Colors := Map()
    Visible := true
    ClickThrough := false

    __New() {
        this.Build()
        this.ApplyConfig()
    }

    Build() {
        this.Colors := Map()
        opt := "+AlwaysOnTop -Caption +ToolWindow +Border"
        if Config.GetBool("Hud", "ClickThrough")
            opt .= " +E0x20"
        this.ClickThrough := Config.GetBool("Hud", "ClickThrough")

        g := Gui(opt)
        g.BackColor := "141414"
        g.MarginX := 12
        g.MarginY := 8

        g.SetFont("s9 bold c6E6E6E", "Segoe UI")
        this.TitleTxt := g.Add("Text", "w300", "ERLC CRUISE CONTROL")

        g.SetFont("s16 bold cWhite", "Segoe UI")
        this.StatusTxt := g.Add("Text", "w300 h30", "CRUISE OFF")

        g.SetFont("s9 c8A8A8A", "Segoe UI")
        g.Add("Text", "w145 Section", "TARGET")
        g.Add("Text", "x+10 yp w145", "SPEED")

        g.SetFont("s24 bold c00E5FF", "Segoe UI")
        this.TargetTxt := g.Add("Text", "xs w145 h44", "--")
        g.SetFont("s24 bold cWhite", "Segoe UI")
        this.SpeedTxt := g.Add("Text", "x+10 yp w145 h44", "--")

        g.SetFont("s9 c8A8A8A", "Segoe UI")
        this.ThrottleTxt := g.Add("Text", "xs w300", "THROTTLE")
        this.Bar := g.Add("Progress", "xs w300 h14 -Theme Range0-100 c00E676 Background333333", 0)

        this.BrakeTxt := g.Add("Text", "xs w300", "BRAKE")
        this.BrakeBar := g.Add("Progress", "xs w300 h14 -Theme Range0-100 cFF5252 Background333333", 0)

        this.AccelTxt := g.Add("Text", "xs w300", "")

        g.SetFont("s10 cWhite", "Segoe UI")
        this.ActionTxt := g.Add("Text", "xs w300 h22 +0x80", "")

        g.SetFont("s9 c9E9E9E", "Consolas")
        this.OcrTxt := g.Add("Text", "xs w300 h34 +0x80", "")

        g.OnEvent("Close", (*) => this.Hide())
        this.Gui := g
    }

    Show() {
        x := Config.GetInt("Hud", "X")
        y := Config.GetInt("Hud", "Y")
        this.Gui.Show(Format("x{} y{} NoActivate", x, y))
        this.Gui.Opt("+LastFound")
        try WinSetTransparent(Config.GetInt("Hud", "Opacity"), this.Gui.Hwnd)
        this.Visible := true
    }

    Hide() {
        this.Gui.Hide()
        this.Visible := false
    }

    ; Applies position, width, opacity, visibility, and click-through from Config.
    ApplyConfig() {
        this.Gui.Move(Config.GetInt("Hud", "X"), Config.GetInt("Hud", "Y"), Config.GetInt("Hud", "Width"))
        if Config.GetBool("Hud", "Visible")
            this.Show()
        else
            this.Hide()
    }

    SetOpacity(value) {
        value := Min(255, Max(30, value))
        Config.Set("Hud", "Opacity", value)
        this.Gui.Opt("+LastFound")
        try WinSetTransparent(value, this.Gui.Hwnd)
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

    ; Enables/disables click-through. WS_EX_TRANSPARENT cannot be toggled
    ; cleanly on a live window, so the overlay is rebuilt with the flag set.
    SetClickThrough(on) {
        on := !!on
        Config.Set("Hud", "ClickThrough", on ? 1 : 0)
        if (this.ClickThrough = on)
            return
        this.Build()
        this.ApplyConfig()
        Logger.Action("HUD click-through " (on ? "on" : "off") ".")
    }

    SetPosition(x, y) {
        this.Gui.Move(x, y)
        Config.Set("Hud", "X", x)
        Config.Set("Hud", "Y", y)
    }

    ; --- rendering ----------------------------------------------------------

    ; Reads the engine's status snapshot and repaints.
    Update(engine) {
        st := engine.Status

        if st.debug
            this.Paint(this.StatusTxt, "DEBUG  (no keys pressed)", "FFD740")
        else if st.active
            this.Paint(this.StatusTxt, "CRUISE ON", "00E676")
        else
            this.Paint(this.StatusTxt, "CRUISE OFF", "FF5252")

        this.Paint(this.TargetTxt, st.target, "00E5FF")

        if (st.speed < 0) {
            this.Paint(this.SpeedTxt, "--", "9E9E9E")
        } else {
            diff := Abs(st.target - st.speed)
            col := !st.active ? "FFFFFF" : diff <= 2 ? "00E676" : diff <= 6 ? "FFD740" : "FF9100"
            this.Paint(this.SpeedTxt, Round(st.speed), col)
        }

        pct := Round(st.duty * 100)
        this.Paint(this.ThrottleTxt, "THROTTLE  " pct "%", "8A8A8A")
        if (this.Bar.Value != pct)
            this.Bar.Value := pct

        bpct := Round(st.brakeDuty * 100)
        this.Paint(this.BrakeTxt, "BRAKE  " bpct "%", bpct > 0 ? "FF5252" : "8A8A8A")
        if (this.BrakeBar.Value != bpct)
            this.BrakeBar.Value := bpct

        sign := st.accel >= 0 ? "+" : ""
        this.Paint(this.AccelTxt, "ACCEL  " sign Round(st.accel, 1) " mph/s", "8A8A8A")
        this.Paint(this.ActionTxt, st.action, "FFFFFF")

        note := st.note
        if (note = "") {
            this.Paint(this.OcrTxt, "", "9E9E9E")
        } else {
            n := StrReplace(note, "`n", " ")
            col := RegExMatch(n, "i)^(error|region|\(empty|no |can't|ignored)") ? "FF5252" : "9E9E9E"
            this.Paint(this.OcrTxt, "OCR: " n, col)
        }
    }

    Paint(ctrl, text, color := "") {
        text := String(text)
        if (ctrl.Value != text)
            ctrl.Value := text
        if (color != "" && (!this.Colors.Has(ctrl) || this.Colors[ctrl] != color)) {
            this.Colors[ctrl] := color
            ctrl.SetFont("c" color)
        }
    }
}
