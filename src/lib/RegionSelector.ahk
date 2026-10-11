; ---------------------------------------------------------------------------
; RegionSelector.ahk - snipping-tool style screen region selection.
;
; Shows a dimmed, full-virtual-screen overlay. The user drags a rectangle which
; is punched through the dimming (even-odd WinSetRegion) so the real screen
; shows inside it, with a coloured frame and a live size + OCR preview label.
; Esc cancels. On release the region is returned (or saved via PickAndSave).
; ---------------------------------------------------------------------------

class RegionSelector {
    ; Runs the interactive selection. Returns {X, Y, W, H} or "" if cancelled.
    static Select() {
        CoordMode "Mouse", "Screen"
        vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)

        dim := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +LastFound")
        dim.BackColor := "000000"
        dim.Show(Format("x{} y{} w{} h{}", vx, vy, vw, vh))
        WinSetTransparent(120, dim.Hwnd)
        try WinActivate("ahk_id " dim.Hwnd)

        frame := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +LastFound +E0x08000000 +E0x20")
        frame.BackColor := "00E5FF"
        frame.Show("Hide")

        tip := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +LastFound +E0x08000000 +E0x20")
        tip.BackColor := "141414"
        tip.MarginX := 8
        tip.MarginY := 4
        tip.SetFont("s10 cWhite", "Segoe UI")
        tipTxt := tip.Add("Text", "w320", "Drag over the speedometer. Esc cancels.")
        tip.Show("Hide")

        ; --- wait for the initial press -------------------------------------
        while !GetKeyState("LButton", "P") {
            if GetKeyState("Escape", "P")
                return this.Cleanup(dim, frame, tip, "")
            Sleep 15
        }

        MouseGetPos(&sx, &sy)
        lastPreview := 0
        preview := ""

        ; --- drag -----------------------------------------------------------
        while GetKeyState("LButton", "P") {
            if GetKeyState("Escape", "P")
                return this.Cleanup(dim, frame, tip, "")

            MouseGetPos(&mx, &my)
            mx := Max(vx, Min(mx, vx + vw))
            my := Max(vy, Min(my, vy + vh))
            r := this.Rect(sx, sy, mx, my)

            ; dim overlay with a hole punched where the selection is
            L := r.X - vx, T := r.Y - vy, Rr := L + r.W, B := T + r.H
            WinSetRegion(Format("0-0 {1}-0 {1}-{2} 0-{2} 0-0 {3}-{4} {5}-{4} {5}-{6} {3}-{6} {3}-{4}"
                , vw, vh, L, T, Rr, B), dim.Hwnd)

            ; frame around the selection
            if (r.W > 4 && r.H > 4) {
                frame.Move(r.X, r.Y, r.W, r.H)
                b := 2
                WinSetRegion(Format("0-0 {1}-0 {1}-{2} 0-{2} 0-0 {3}-{3} {4}-{3} {4}-{5} {3}-{5} {3}-{3}"
                    , r.W, r.H, b, r.W - b, r.H - b), frame.Hwnd)
                frame.Show("NoActivate")
            }

            ; preview label below the selection (flips above near the bottom edge)
            tx := r.X
            ty := (r.Y + r.H + 6 + 30 > vy + vh) ? r.Y - 34 : r.Y + r.H + 6
            tip.Move(tx, ty)

            now := A_TickCount
            if (r.W >= 5 && r.H >= 5 && now - lastPreview >= 200) {
                lastPreview := now
                preview := this.PreviewText(r.X, r.Y, r.W, r.H)
            }
            tipTxt.Value := Format("{} x {}   {}", r.W, r.H, preview)
            tip.Show("NoActivate")

            Sleep 15
        }

        ; --- finalise -------------------------------------------------------
        MouseGetPos(&mx, &my)
        mx := Max(vx, Min(mx, vx + vw))
        my := Max(vy, Min(my, vy + vh))
        r := this.Rect(sx, sy, mx, my)

        this.Cleanup(dim, frame, tip)

        if (r.W < 5 || r.H < 5)
            return ""
        return r
    }

    ; Selects and persists the region to config. Returns true on success.
    static PickAndSave() {
        r := this.Select()
        if (r = "") {
            Logger.Action("Region selection cancelled.")
            return false
        }
        Config.SetRegion(r.X, r.Y, r.W, r.H)
        Logger.Action(Format("Region set to {1},{2} {3}x{4}.", r.X, r.Y, r.W, r.H))
        return true
    }

    ; --- helpers ------------------------------------------------------------

    static Rect(x1, y1, x2, y2) {
        return {X: Min(x1, x2), Y: Min(y1, y2), W: Abs(x2 - x1), H: Abs(y2 - y1)}
    }

    static PreviewText(x, y, w, h) {
        try {
            lang := Config.Get("Ocr", "Language", "en-us")
            result := OCR.FromRect(x, y, w, h, {lang: lang, scale: 2})
            t := Trim(StrReplace(result.Text, "`n", " "))
            return (t = "") ? "(no text)" : "'" t "'"
        } catch as e {
            return "(" e.Message ")"
        }
    }

    static Cleanup(dim, frame, tip, ret := "") {
        for g in [dim, frame, tip] {
            try g.Destroy()
        }
        return ret
    }
}
