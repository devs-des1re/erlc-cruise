; ---------------------------------------------------------------------------
; Logger.ahk - timestamped session log plus a persistent errors.log.
;
; Session logs: %APPDATA%\ERLCCruise\logs\<yyyy-MM-dd>.log
; Errors:       %APPDATA%\ERLCCruise\logs\errors.log
; Logging can be disabled from settings; errors are always recorded.
;
; Logger.Install() wires up global OnError/OnExit handlers so uncaught errors
; and abrupt exits are always captured.
; ---------------------------------------------------------------------------

class Logger {
    static Enabled := true

    static EnsureDirs() {
        if !DirExist(Paths.LogsDir)
            DirCreate(Paths.LogsDir)
    }

    static SessionFile() {
        return Paths.LogsDir "\" FormatTime(, "yyyy-MM-dd") ".log"
    }

    static ErrorFile() {
        return Paths.LogsDir "\errors.log"
    }

    static Info(message) {
        if !this.Enabled
            return
        this.Write("INFO ", message)
    }

    static Debug(message) {
        if !this.Enabled
            return
        this.Write("DEBUG", message)
    }

    static Warn(message) {
        if !this.Enabled
            return
        this.Write("WARN ", message)
    }

    ; Cruise actions: toggles, target changes, region selection, key sends.
    static Action(message) {
        if !this.Enabled
            return
        this.Write("ACTION", message)
    }

    ; Errors are always written, even when normal logging is off.
    static Err(message) {
        this.EnsureDirs()
        this.Append(this.ErrorFile(), "ERROR", message)
        if this.Enabled
            this.Append(this.SessionFile(), "ERROR", message)
    }

    static Exception(e, context := "") {
        text := (context != "" ? context ": " : "") e.Message
        if (e.HasProp("File") && e.File != "")
            text .= " (" e.File ":" e.Line ")"
        this.Err(text)
    }

    ; Installs global handlers so nothing is lost. Safe to call once at startup.
    static Install() {
        OnError(this.__OnError.Bind(this))
        OnExit(this.__OnExit.Bind(this))
    }

    static __OnError(err, mode) {
        try {
            this.Exception(err, "Unhandled")
            if Logger.Enabled
                this.Warn("Stack: " this.StackText(err))
        } catch {
            ; Never let the error handler itself throw.
        }
        return false  ; Let AutoHotkey show its default dialog as well.
    }

    static __OnExit(reason, code) {
        try {
            this.Info(Format("Exiting (reason {1}, code {2}).", reason, code))
        } catch {
            ; Best-effort.
        }
    }

    static StackText(err) {
        text := ""
        if err.HasProp("Stack") && err.Stack != "" {
            for line in StrSplit(err.Stack, "`n")
                text .= Trim(line) " | "
        }
        return RTrim(text, " |")
    }

    static Write(level, message) {
        this.EnsureDirs()
        this.Append(this.SessionFile(), level, message)
    }

    static Append(file, level, message) {
        stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        line := stamp " [" level "] " message "`r`n"
        try
            FileAppend(line, file, "UTF-8")
        catch
            ; Never let logging failure cascade into a crash.
            return false
        return true
    }
}
