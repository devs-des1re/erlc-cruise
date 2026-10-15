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
        this.Ctrl.LoadConfig()
        this.Input := InputDriver()
        this.Target := this.ClampTarget(Config.GetInt("General", "StartTarget"))
        this.TickFn := this.Tick.Bind(this)
        this.PwmFn := this.Pwm.Bind(this)
        this.Note := ""
        this.BuildStatus()
    }

    ; Re-reads all tuning from Config and applies live changes.
    Reload() {
        this.Ctrl.LoadConfig()
        this.ApplyTickInterval()
        if !this.Active
            this.Target := this.ClampTarget(Config.GetInt("General", "StartTarget"))
    }

    ; --- timers -------------------------------------------------------------

    ; Update interval, clamped so 0 (which would stop the timer) can't sneak in.
    TickInterval() {
        return Max(30, Config.GetInt("General", "UpdateInterval"))
    }

    ; Applies the configured tick interval to the running timer. Called at
    ; startup and again on every reload so the setting takes effect live.
    ApplyTickInterval() {
        SetTimer(this.TickFn, this.TickInterval())
    }

    StartTimers() {
        this.ApplyTickInterval()
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
            this.Target := this.ClampTarget(read.Speed)

        this.Reader.Reset(read.Speed)
        this.Ctrl.PrimeStart(read.Speed)
        this.Active := true
        this.LastAction := "Cruise ON, target " this.Target
        Logger.Action("Cruise ON (target " this.Target ", speed " read.Speed ").")
        this.BuildStatus()
    }

    Stop(reason := "Cruise off") {
        if this.Active {
            this.Ctrl.MaybePersist(this.Target, this.Reader.LastSpeed)
            this.PersistLearnedDuty()
        }
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
        this.Target := this.ClampTarget(this.Target + delta)
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

    ClampTarget(speed) {
        return Min(Config.MaxTargetSpeed, Max(0, speed))
    }

    ; Writes the controller's learned hold-throttle back to Config and the
    ; active profile, so each vehicle keeps what it learned across sessions.
    PersistLearnedDuty() {
        duty := this.Ctrl.LearnedDuty
        Config.Set("Controller", "LearnedDuty", duty)
        active := Profiles.Active()
        if (active != "")
            Profiles.SetValue(active, "Controller", "LearnedDuty", duty)
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

    OnThrottlePressed() {
        if (this.Active && !this.Input.InThrottleGuard())
            this.Stop("Accelerated")
    }

    ; If cruise is running but the game window no longer has focus, stop so our
    ; held throttle/brake keys never leak into whatever window took focus.
    CheckFocus() {
        if (this.Active && !GameWindow.IsActive())
            this.Stop("Game window lost focus")
    }

    ; --- loop ---------------------------------------------------------------

    Tick() {
        this.CheckFocus()
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
        this.CheckFocus()
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
