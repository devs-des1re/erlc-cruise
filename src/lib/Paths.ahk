; ---------------------------------------------------------------------------
; Paths.ahk - central path resolution for ERLC Cruise Control
; Resolves the vendored OCR library and the per-user data directory under %APPDATA%.
; ---------------------------------------------------------------------------

class Paths {
    static AppDataDir := EnvGet("APPDATA") "\ERLCCruise"
    static LogsDir    := Paths.AppDataDir "\logs"
    static CapturesDir := Paths.AppDataDir "\captures"
    static ConfigFile := Paths.AppDataDir "\config.ini"

    static IconFile   := Paths.FindIcon()
    static UiDir      := Paths.FindUiDir()
    static LoaderFile := Paths.FindLoaderFile()

    ; WebView2 user-data folders. Each WebView window in a process needs its
    ; own folder, so the settings window and the HUD use separate ones.
    static WebViewDataDir    := Paths.AppDataDir "\webview"
    static WebViewHudDataDir := Paths.AppDataDir "\webview-hud"

    ; Locate icon.ico whether running from source (src/lib) or installed next
    ; to the exe. Returns a normalized absolute path (no "..") since Windows'
    ; toast icon resolver rejects unnormalized paths.
    static FindIcon() {
        rels := ["\..\..\icon.ico", "\..\icon.ico", "\icon.ico"]
        for rel in rels {
            f := A_ScriptDir rel
            if FileExist(f) {
                buf := Buffer(520, 0)
                if DllCall("GetFullPathNameW", "Str", f, "UInt", 260, "Ptr", buf, "Ptr", 0, "UInt")
                    return StrGet(buf)
                return f
            }
        }
        return ""
    }

    ; Locate the ui\ folder. Installed builds ship it next to the exe; source
    ; runs keep it at the repository root (two levels above src\lib).
    static FindUiDir() {
        rels := A_IsCompiled ? ["\ui", "\..\ui"] : ["\..\..\ui", "\..\ui", "\ui"]
        for rel in rels {
            dir := A_ScriptDir rel
            if FileExist(dir "\index.html")
                return dir
        }
        return A_ScriptDir "\..\..\ui"
    }

    ; Locate the WebView2 loader DLL (shipped with the app).
    static FindLoaderFile() {
        rels := ["\WebView2Loader.dll"
               , "\vendor\webview\64bit\WebView2Loader.dll"
               , "\..\vendor\webview\64bit\WebView2Loader.dll"
               , "\..\..\vendor\webview\64bit\WebView2Loader.dll"
               , "\..\..\..\vendor\webview\64bit\WebView2Loader.dll"]
        for rel in rels {
            f := A_ScriptDir rel
            if FileExist(f)
                return f
        }
        return "WebView2Loader.dll"
    }

    static EnsureDataDirs() {
        dirs := [this.AppDataDir, this.LogsDir, this.CapturesDir, this.WebViewDataDir, this.WebViewHudDataDir]
        for dir in dirs {
            if !DirExist(dir)
                DirCreate(dir)
        }
    }
}
