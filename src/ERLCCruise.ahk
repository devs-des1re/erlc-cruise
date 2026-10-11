; ---------------------------------------------------------------------------
; ERLC Cruise Control - reads your speed from screen via offline OCR and holds
; it automatically, acting as an in-game cruise control.
;
; ERLC Cruise Control is an independent tool and is not affiliated with,
; endorsed by, or associated with ERLC or Roblox Corporation.
; ---------------------------------------------------------------------------

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

;@Ahk2Exe-SetMainIcon %A_ScriptDir%\..\icon.ico
;@Ahk2Exe-SetName ERLC Cruise Control
;@Ahk2Exe-SetDescription ERLC Cruise Control
;@Ahk2Exe-SetCompanyName ERLC Cruise Control
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Arjun Patel

; Embedded Web UI (served from exe resources when compiled). Resource names
; must match the uppercased request path: "/fonts/x.ttf" -> "FONTS\X.TTF".
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\index.html, INDEX.HTML
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\style.css, STYLE.CSS
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\app.js, APP.JS
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\icon.png, ICON.PNG
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Light.ttf, FONTS\OUTFIT-LIGHT.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Regular.ttf, FONTS\OUTFIT-REGULAR.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Medium.ttf, FONTS\OUTFIT-MEDIUM.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-SemiBold.ttf, FONTS\OUTFIT-SEMIBOLD.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Bold.ttf, FONTS\OUTFIT-BOLD.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\vendor\webview\64bit\WebView2Loader.dll, 64bit\WebView2Loader.dll

#Include %A_ScriptDir%\version.ahk
#Include %A_ScriptDir%\lib\Paths.ahk
#Include %A_ScriptDir%\lib\Logger.ahk
#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\OCR.ahk
#Include %A_ScriptDir%\lib\SpeedParser.ahk
#Include %A_ScriptDir%\lib\InputDriver.ahk
#Include %A_ScriptDir%\lib\Controller.ahk
#Include %A_ScriptDir%\lib\SpeedReader.ahk
#Include %A_ScriptDir%\lib\GameWindow.ahk
#Include %A_ScriptDir%\lib\CruiseEngine.ahk
#Include %A_ScriptDir%\lib\RegionSelector.ahk
#Include %A_ScriptDir%\..\vendor\JSON.ahk
#Include %A_ScriptDir%\..\vendor\webview\WebViewToo.ahk
#Include %A_ScriptDir%\lib\Hud.ahk
#Include %A_ScriptDir%\lib\Ui.ahk

; --- hotkey management -------------------------------------------------------
; Every hotkey fires only while the game window is focused, so typing in any
; other application never triggers a capture, region pick, or cruise action.
class Hotkeys {
    static Keys := ["Region", "Settings", "ToggleHud", "Toggle", "IncrementUp", "IncrementDown", "Debug", "Cancel"]
    static Registered := []

    ; Clears previous registrations and re-registers everything from Config.
    static Register() {
        static Handlers := Map(
            "Region", (*) => App.SelectRegion(),
            "Settings", (*) => App.OpenSettings(),
            "ToggleHud", (*) => App.ToggleHud(),
            "Toggle", (*) => gEngine.Toggle(),
            "IncrementUp", (*) => gEngine.IncrementUp(),
            "IncrementDown", (*) => gEngine.IncrementDown(),
            "Debug", (*) => gEngine.ToggleDebug(),
            "Cancel", (*) => gEngine.OnBrakePressed()
        )

        ; Turn off every combo we previously registered, so a rebind (or a
        ; cleared field) never leaves a stale hotkey active.
        HotIf()
        for prev in this.Registered {
            try Hotkey prev, "Off"
        }
        this.Registered := []

        ; Scope every hotkey to the game window.
        HotIf((*) => GameWindow.IsActive())
        for name in this.Keys
            this.RegisterOne(name, Handlers[name])

        HotIf()  ; restore global context
    }

    static RegisterOne(name, fn) {
        key := Config.GetHotkey(name)
        if (key = "")
            return
        try {
            Hotkey key, fn, "On"
            this.Registered.Push(key)
            Logger.Info("Registered hotkey " name " = " key ".")
        } catch as e {
            Logger.Exception(e, "Register hotkey " name)
            App.Notify("Could not register " name " hotkey: " key)
        }
    }
}

; --- app helpers -------------------------------------------------------------
class App {
    static Notify(title, message) {
        ; Option 4 = use the tray icon as the toast logo.
        try TrayTip(message, title, 4)
    }

    static SelectRegion() {
        if RegionSelector.PickAndSave()
            this.Notify("ERLC Cruise Control", "Speed region saved.")
        gEngine.BuildStatus()
    }

    static ToggleHud() {
        gHud.ToggleVisible()
    }

    static OpenSettings() {
        Ui.Open()
    }

    static OpenDataFolder() {
        Run Paths.AppDataDir
    }

    static OpenLogs() {
        Run Paths.LogsDir
    }

    static Quit() {
        Logger.Info("Exiting by user request.")
        ExitApp()
    }
}

; --- shell identity ----------------------------------------------------------
; Windows shows the AppUserModelID's display name and icon on toast
; notifications. Without this they default to "AutoHotkey" and its icon.
class Shell {
    static AppId := "ERLCCruiseControl"

    static RegisterIdentity() {
        key := "HKCU\SOFTWARE\Classes\AppUserModelId\" this.AppId
        try {
            RegWrite(this.AppId, "REG_SZ", key, "DisplayName")
            if (Paths.IconFile != "" && FileExist(Paths.IconFile))
                RegWrite(Paths.IconFile, "REG_SZ", key, "IconUri")
        } catch {
            ; Registry write is best-effort; notifications still work.
        }
        try DllCall("shell32\SetCurrentProcessExplicitAppUserModelID", "wstr", this.AppId)
    }
}

; --- startup -----------------------------------------------------------------
Paths.EnsureDataDirs()
Config.Load()
Logger.Install()
Logger.Enabled := Config.GetBool("Settings", "Logging")
Shell.RegisterIdentity()
Logger.Info("ERLC Cruise Control started (" AppVersion ").")
Logger.Info("Data folder: " Paths.AppDataDir)

global gEngine := CruiseEngine()
gEngine.Input.InstallExitRelease()
gEngine.StartTimers()
Logger.Info("Engine initialised.")

global gHud := Hud()
SetTimer(RefreshHud.Bind(gHud, gEngine), 100)
Logger.Info("HUD initialised.")

RefreshHud(hud, engine) {
    hud.Update(engine)
}

Hotkeys.Register()

if !Config.HasRegion()
    App.Notify("ERLC Cruise Control", "No speed region set. Use the region hotkey to pick one.")

; Show the settings window and the HUD on launch. Closing either window hides
; it to the tray; the app keeps running.
try {
    Ui.Open()
    Logger.Info("Settings window shown.")
} catch as e {
    Logger.Exception(e, "Open settings on startup")
    App.Notify("ERLC Cruise Control", "Could not open the settings window: " e.Message)
}
gHud.SetVisible(true)

; --- tray --------------------------------------------------------------------
A_IconTip := "ERLC Cruise Control"
if (Paths.IconFile != "" && FileExist(Paths.IconFile))
    TraySetIcon(Paths.IconFile)
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Open GUI", (*) => App.OpenSettings())
Tray.Add("Toggle HUD", (*) => App.ToggleHud())
Tray.Add()
Tray.Add("Quit", (*) => App.Quit())
Tray.Default := "Open GUI"
Tray.ClickCount := 1  ; single left-click opens the settings window
