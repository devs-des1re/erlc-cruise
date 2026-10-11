; ---------------------------------------------------------------------------
; SpeedParser.ahk - pure conversion of OCR text into a speed number.
;
; Strips the "MPH" suffix, fixes glyphs OCR commonly confuses for digits, and
; keeps digits only. Returns -1 when no plausible speed is found.
;
; Kept pure (no state, no IO) so it stays trivially testable.
; ---------------------------------------------------------------------------

class SpeedParser {
    ; Parses raw OCR text. Returns an integer speed, or -1 on failure.
    ; `&clean` receives the pre-normalisation text for logging/debugging.
    static Parse(raw, &clean := "") {
        t := RegExReplace(raw, "i)m\s*[pr].*$", "")   ; cut off "MPH" and anything after it
        clean := Trim(t)
        ; fix letters OCR commonly mistakes for digits (done AFTER removing MPH)
        t := StrReplace(t, "O", "0")
        t := StrReplace(t, "I", "1")
        t := StrReplace(t, "L", "1")
        t := StrReplace(t, "|", "1")
        t := StrReplace(t, "S", "5")
        t := StrReplace(t, "B", "8")
        t := RegExReplace(t, "[^0-9]", "")            ; keep digits only
        if (t = "" || StrLen(t) > 3)
            return -1
        return Integer(t)
    }
}
