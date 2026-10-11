; ---------------------------------------------------------------------------
; InputDriver.ahk - holds/releases the throttle and brake keys.
;
; Wraps the send-key logic with held-state tracking and a brake guard window so
; the engine can tell its own brake taps apart from a real player brake press.
; ---------------------------------------------------------------------------

class InputDriver {
    ThrottleKey := "w"
    BrakeKey    := "s"
    GuardMs     := 300

    Wheld := false
    Sheld := false
    BrakeGuardUntil := 0

    __New(throttleKey := "w", brakeKey := "s") {
        this.ThrottleKey := throttleKey
        this.BrakeKey := brakeKey
    }

    ; --- throttle -----------------------------------------------------------

    HoldThrottle() {
        if !this.Wheld {
            Send "{" this.ThrottleKey " down}"
            this.Wheld := true
        }
    }

    ReleaseThrottle() {
        if this.Wheld {
            Send "{" this.ThrottleKey " up}"
            this.Wheld := false
        }
    }

    ; --- brake --------------------------------------------------------------

    HoldBrake() {
        if !this.Sheld {
            this.BrakeGuardUntil := A_TickCount + this.GuardMs
            Send "{" this.BrakeKey " down}"
            this.Sheld := true
        }
    }

    ReleaseBrake() {
        if this.Sheld {
            this.BrakeGuardUntil := A_TickCount + this.GuardMs
            Send "{" this.BrakeKey " up}"
            this.Sheld := false
        }
    }

    ; --- queries ------------------------------------------------------------

    BrakeHeld => this.Sheld
    ThrottleHeld => this.Wheld

    ; True while a real player brake press should be ignored (it is our own
    ; brake going down/up). Used by the ~s cancel handler.
    InBrakeGuard() {
        return A_TickCount < this.BrakeGuardUntil
    }

    ; --- lifecycle ----------------------------------------------------------

    ; Releases everything. Safe to call repeatedly.
    ReleaseAll() {
        this.ReleaseThrottle()
        this.ReleaseBrake()
    }

    ; Installs an OnExit handler that always releases keys so nothing sticks.
    InstallExitRelease() {
        this.__exitFn := this.__OnExit.Bind(this)
        OnExit(this.__exitFn)
    }

    __OnExit(*) {
        this.ReleaseAll()
    }
}
