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

; --- startup -----------------------------------------------------------------
; Later phases add the region selector and the WebView2 UI here.

Paths.EnsureDataDirs()
Config.Load()
Logger.Install()
Logger.Enabled := Config.GetBool("Settings", "Logging")
Logger.Info("ERLC Cruise Control started (" AppVersion ").")
Logger.Info("Data folder: " Paths.AppDataDir)

Engine := CruiseEngine()
Engine.Input.InstallExitRelease()
Engine.StartTimers()
Logger.Info("Engine initialised.")

HudOverlay := Hud()
SetTimer(RefreshHud.Bind(HudOverlay, Engine), 100)
Logger.Info("HUD initialised.")

RefreshHud(hud, engine) {
    hud.Update(engine)
}

; --- tray --------------------------------------------------------------------
A_IconTip := "ERLC Cruise Control"
if (Paths.IconFile != "" && FileExist(Paths.IconFile))
    TraySetIcon(Paths.IconFile)
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Close App", (*) => ExitApp())
