; ---------------------------------------------------------------------------
; SpeedReader.ahk - reads the speedometer region with OCR and smooths readings.
;
; Wraps the vendored OCR library's FromRect capture, converts text via
; SpeedParser, rejects implausible jumps, and maintains a smoothed speed plus
; an acceleration estimate.
;
; Port of the prototype's ReadSpeed()/Tick() measurement half.
; ---------------------------------------------------------------------------

class SpeedReader {
    LastSpeed := -1        ; smoothed speed, -1 until first read
    Accel := 0.0           ; mph/s estimate
    LastReadTick := 0
    LastDt := 0.0          ; seconds between the last two accepted readings
    BadReads := 0
    Raw := ""              ; last OCR text (or reason) for logging/HUD

    ; Reads the configured region once. Returns:
    ;   {Speed, Raw, Error}  - Speed >= 0 on success, -1 on failure.
    ; Raw carries the OCR text (or a human-readable reason) for logging/HUD.
    ReadOnce() {
        raw := ""
        if !Config.HasRegion()
            return {Speed: -1, Raw: "REGION NOT SET", Error: true}

        r := Config.GetRegion()
        opts := this.BuildOptions()
        try {
            try {
                result := OCR.FromRect(r.X, r.Y, r.W, r.H, opts)
            } catch {
                result := OCR.FromRect(r.X, r.Y, r.W, r.H)
            }
            raw := Trim(result.Text)
            if (raw = "") {
                raw := "(empty: OCR saw no text, region may be wrong)"
            } else {
                n := SpeedParser.Parse(raw, &clean)
                if (n >= 0)
                    return {Speed: n, Raw: raw, Error: false}
                raw := "no number in '" StrReplace(raw, "`n", " ") "'"
            }
        } catch as e {
            raw := "ERROR: " e.Message
        }
        return {Speed: -1, Raw: raw, Error: true}
    }

    ; Builds OCR options from Config. Falls back to scale-only when unsupported
    ; option keys are rejected by the library.
    BuildOptions() {
        opts := {Language: Config.Get("Ocr", "Language"), lang: Config.Get("Ocr", "Language")}
        scale := Config.GetInt("Ocr", "Scale")
        if (scale > 1)
            opts.scale := scale
        if Config.GetBool("Ocr", "Grayscale")
            opts.grayscale := 1
        if Config.GetBool("Ocr", "InvertColors")
            opts.invertcolors := 1
        mono := Config.GetInt("Ocr", "Monochrome")
        if (mono > 0)
            opts.monochrome := mono
        return opts
    }

    ; Folds a raw reading into the smoothed estimate. Returns one of:
    ;   "ok"      - accepted and smoothed
    ;   "jumped"  - implausible jump, ignored
    ;   "first"   - first reading (or after a gap), reset the estimate
    ;   "error"   - reading failed
    Update(rawSpeed, rawText) {
        now := A_TickCount
        if (rawSpeed < 0) {
            this.Raw := rawText
            return "error"
        }
        if (this.LastSpeed >= 0 && Abs(rawSpeed - this.LastSpeed) > 20 && this.BadReads < 4) {
            this.BadReads++
            return "jumped"
        }
        this.BadReads := 0
        dt := (now - this.LastReadTick) / 1000
        this.LastDt := dt

        if (this.LastSpeed < 0 || dt > 1.5) {
            this.LastSpeed := rawSpeed
            this.Accel := 0
            this.LastReadTick := now
            this.Raw := rawText
            return "first"
        }

        if (dt > 0.01) {
            prev := this.LastSpeed
            this.LastSpeed += 0.5 * (rawSpeed - this.LastSpeed)
            this.Accel += 0.3 * (((this.LastSpeed - prev) / dt) - this.Accel)
        }
        this.LastReadTick := now
        this.Raw := rawText
        return "ok"
    }

    ; Resets all measurement state (used when cruise starts).
    Reset(speed := -1) {
        this.LastSpeed := speed
        this.Accel := 0
        this.LastDt := 0
        this.BadReads := 0
        this.Raw := ""
        this.LastReadTick := (speed >= 0) ? A_TickCount : 0
    }

    ; Seconds since the last successful reading.
    SecondsSinceRead() {
        return (this.LastReadTick = 0) ? 9999 : (A_TickCount - this.LastReadTick) / 1000
    }
}
