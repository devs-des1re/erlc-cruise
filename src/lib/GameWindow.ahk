; ---------------------------------------------------------------------------
; GameWindow.ahk - locating and detecting focus of the game window.
;
; Hotkeys are scoped with HotIf(GameWindow.IsActive) so the cruise controls
; only fire while the game is focused. The target process is configurable.
; ---------------------------------------------------------------------------

class GameWindow {
    ; Returns the win title criterion, e.g. "ahk_exe RobloxPlayerBeta.exe".
    static WinTitle() {
        proc := Config.Get("Settings", "GameProcess", "RobloxPlayerBeta.exe")
        return "ahk_exe " proc
    }

    static IsActive() {
        return WinActive(this.WinTitle()) != 0
    }

    static Exists() {
        return WinExist(this.WinTitle()) != 0
    }
}
