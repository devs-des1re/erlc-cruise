; ---------------------------------------------------------------------------
; CruiseEngine.ahk - the cruise state machine and tick loop.
;
; Owns the reader, controller, and input driver; runs a periodic tick that
; reads speed, updates the controller, and drives pulse-width-modulated throttle
; and brake. Exposes Toggle/Stop/Adjust/Debug and a status snapshot for the HUD
; and settings UI.
;
; Port of the prototype's Tick()/ToggleCruise()/StopCruise()/AdjustTarget()/
; ToggleDebug()/Pwm() and its ~s cancel guard.
; ---------------------------------------------------------------------------

class CruiseEngine {
    Active := false
    Debug := false
    Target := 40
    LastAction := "Ready"

    ; Last status snapshot, consumed by the HUD / UI.
    Status := ""

    __New() {
        this.Reader := SpeedReader()
        this.Ctrl := Controller()
        this.Input := InputDriver()
        this.Target := Config.GetInt("General", "StartTarget")
        this.TickFn := this.Tick.Bind(this)
        this.PwmFn := this.Pwm.Bind(this)
        this.Note := ""
        this.BuildStatus()
    }

    ; Re-reads all tuning from Config and applies live changes.
    Reload() {
        this.Ctrl.LoadConfig()
        if !this.Active
            this.Target := Config.GetInt("General", "StartTarget")
    }

    ; --- timers -------------------------------------------------------------

    StartTimers() {
        SetTimer(this.TickFn, Config.GetInt("General", "UpdateInterval"))
        SetTimer(this.PwmFn, 20)
    }

    StopTimers() {
        SetTimer(this.TickFn, 0)
        SetTimer(this.PwmFn, 0)
    }

    ; --- public controls ----------------------------------------------------

    Toggle() {
        if this.Active
            return this.Stop("Toggled off")

        raw := ""
        read := this.Reader.ReadOnce()
        if (read.Speed < 0) {
            this.LastAction := "Can't read speed"
            Logger.Warn("Toggle failed: " read.Raw)
            this.BuildStatus(read.Raw)
            return
        }

        if Config.GetBool("General", "LockCurrentSpeedOnToggle")
            this.Target := read.Speed

        this.Reader.Reset(read.Speed)
        this.Ctrl.PrimeStart(read.Speed)
        this.Active := true
        this.LastAction := "Cruise ON, target " this.Target
        Logger.Action("Cruise ON (target " this.Target ", speed " read.Speed ").")
        this.BuildStatus()
    }

    Stop(reason := "Cruise off") {
        if this.Active
            this.Ctrl.MaybePersist(this.Target, this.Reader.LastSpeed)
        this.Active := false
        this.Ctrl.Duty := 0
        this.Ctrl.BrakeDuty := 0
        this.Input.ReleaseAll()
        this.LastAction := reason
        Logger.Action("Cruise OFF (" reason ").")
        this.BuildStatus()
    }

    Adjust(delta) {
        if this.Debug {
            this.LastAction := "Debug: target change ignored"
            this.BuildStatus()
            return
        }
        this.Target := Max(0, this.Target + delta)
        this.LastAction := "Target " (delta > 0 ? "increased" : "decreased") " to " this.Target
        Logger.Action("Target adjusted to " this.Target ".")
        this.BuildStatus()
    }

    IncrementUp() {
        this.Adjust(Config.GetInt("General", "Increment"))
    }

    IncrementDown() {
        this.Adjust(-Config.GetInt("General", "Increment"))
    }

    ToggleDebug() {
        this.Debug := !this.Debug
        if this.Debug {
            this.Input.ReleaseAll()
            this.Ctrl.BrakeDuty := 0
        }
        this.LastAction := this.Debug ? "Debug on (no keys pressed)" : "Debug off"
        Logger.Action(this.LastAction)
        this.BuildStatus()
    }

    ; Called by the ~s handler: a real player brake press cancels cruise.
    OnBrakePressed() {
        if (this.Active && !this.Input.Sheld && !this.Input.InBrakeGuard())
            this.Stop("Braked")
    }

    ; --- loop ---------------------------------------------------------------

    Tick() {
        read := this.Reader.ReadOnce()
        state := this.Reader.Update(read.Speed, read.Raw)

        if (state = "error") {
            if (this.Active && this.Reader.SecondsSinceRead() > 1.5)
                this.Stop("Lost speed reading")
            this.BuildStatus(read.Raw)
            return
        }
        if (state = "jumped") {
            this.BuildStatus("ignored jump to " read.Speed)
            return
        }

        if (this.Active && !this.Debug)
            this.Ctrl.Step(this.Target, this.Reader.LastSpeed, this.Reader.Accel, this.Reader.LastDt)

        this.BuildStatus("read " read.Speed)
    }

    ; Pulse-width modulation: holds throttle for duty% of each PWM cycle.
    Pwm() {
        if (!this.Active || this.Debug)
            return
        if (this.Ctrl.BrakeDuty > 0) {
            this.Input.ReleaseThrottle()
            this.Input.HoldBrake()
            return
        }
        this.Input.ReleaseBrake()
        phase := Mod(A_TickCount, this.Ctrl.PwmPeriod) / this.Ctrl.PwmPeriod
        if (this.Ctrl.Duty >= 1 || (this.Ctrl.Duty > 0 && phase < this.Ctrl.Duty))
            this.Input.HoldThrottle()
        else
            this.Input.ReleaseThrottle()
    }

    ; --- status -------------------------------------------------------------

    BuildStatus(note?) {
        if IsSet(note)
            this.Note := note
        if !this.HasOwnProp("Note")
            this.Note := ""

        this.Status := {
            active: this.Active,
            debug: this.Debug,
            target: this.Target,
            speed: this.Reader.LastSpeed,
            accel: this.Reader.Accel,
            duty: this.Ctrl.Duty,
            brakeDuty: this.Ctrl.BrakeDuty,
            action: this.LastAction,
            note: this.Note,
            regionSet: Config.HasRegion()
        }
    }
}
