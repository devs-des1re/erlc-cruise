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
#Include %A_ScriptDir%\lib\Hud.ahk
#Include %A_ScriptDir%\lib\RegionSelector.ahk

; --- hotkey management -------------------------------------------------------
; Cruise-control hotkeys fire only while the game is focused (unless disabled
; in settings). Utility hotkeys (region select, HUD toggle, settings) are always
; global so they work regardless of focus.
class Hotkeys {
    static AlwaysKeys := ["Region", "Settings", "ToggleHud"]
    static GameKeys := ["Toggle", "IncrementUp", "IncrementDown", "Debug", "Cancel"]

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

        ; Clear previous registrations.
        HotIf()
        for name, hk in Handlers {
            key := Config.GetHotkey(name)
            if (key != "") {
                try Hotkey key, "Off"
            }
        }

        onlyFocused := Config.GetBool("Settings", "OnlyWhenFocused")

        ; Global utility hotkeys.
        HotIf()
        for name in this.AlwaysKeys
            this.RegisterOne(name, Handlers[name])

        ; Game hotkeys.
        if onlyFocused
            HotIf((*) => GameWindow.IsActive())
        else
            HotIf()
        for name in this.GameKeys
            this.RegisterOne(name, Handlers[name])

        HotIf()  ; restore global context
    }

    static RegisterOne(name, fn) {
        key := Config.GetHotkey(name)
        if (key = "")
            return
        try {
            Hotkey key, fn, "On"
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
        ; Phase 7 adds the WebView2 settings window.
        this.Notify("ERLC Cruise Control", "Settings UI is coming in the next update.")
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

; --- tray --------------------------------------------------------------------
A_IconTip := "ERLC Cruise Control"
if (Paths.IconFile != "" && FileExist(Paths.IconFile))
    TraySetIcon(Paths.IconFile)
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Select Region", (*) => App.SelectRegion())
Tray.Add("Toggle HUD", (*) => App.ToggleHud())
Tray.Add("Settings", (*) => App.OpenSettings())
Tray.Add()
Tray.Add("Open Data Folder", (*) => App.OpenDataFolder())
Tray.Add("Open Logs", (*) => App.OpenLogs())
Tray.Add()
Tray.Add("Close App", (*) => App.Quit())
Tray.Default := "Select Region"
