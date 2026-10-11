; ---------------------------------------------------------------------------
; Controller.ahk - PID-style controller deciding throttle and brake demand.
;
; Given the current smoothed speed and acceleration, produces a throttle duty
; (0..1) and a brake flag (0/1). Tuning is loaded from Config at construction
; and can be reloaded live from the settings UI.
;
; Port of the prototype's Control() logic.
; ---------------------------------------------------------------------------

class Controller {
    ; tuning (loaded from Config)
    PwmPeriod := 300
    Kp := 0.08
    Ki := 0.02
    Kd := 0.05
    FullThrottleGap := 10
    BrakeSoftGap := 4
    BrakeHardGap := 8
    BrakeAccelThreshold := 2.0
    BrakeReleaseGap := 1.5
    BrakeLookahead := 0.6
    MinBrakeHold := 500
    MinBrakeSpeed := 8

    ; state
    Integral := 0.4
    LearnedDuty := 0.4
    Duty := 0.0
    BrakeDuty := 0
    BrakeChangeTick := 0

    ; Loads tuning values from Config. Call again to apply live changes.
    LoadConfig() {
        c := Config
        this.PwmPeriod            := c.GetInt("Controller", "PwmPeriod")
        this.Kp                   := c.GetFloat("Controller", "Kp")
        this.Ki                   := c.GetFloat("Controller", "Ki")
        this.Kd                   := c.GetFloat("Controller", "Kd")
        this.FullThrottleGap      := c.GetInt("Controller", "FullThrottleGap")
        this.BrakeSoftGap         := c.GetInt("Controller", "BrakeSoftGap")
        this.BrakeHardGap         := c.GetInt("Controller", "BrakeHardGap")
        this.BrakeAccelThreshold  := c.GetFloat("Controller", "BrakeAccelThreshold")
        this.BrakeReleaseGap      := c.GetFloat("Controller", "BrakeReleaseGap")
        this.BrakeLookahead       := c.GetFloat("Controller", "BrakeLookahead")
        this.MinBrakeHold         := c.GetInt("Controller", "MinBrakeHold")
        this.MinBrakeSpeed        := c.GetInt("Controller", "MinBrakeSpeed")
    }

    ; Re-initialises the learned hold-throttle when cruise starts.
    PrimeStart(speedEst) {
        this.Integral := this.LearnedDuty
        this.Duty := this.LearnedDuty
        this.BrakeDuty := 0
    }

    ; Persists the learned throttle when cruise stops near the target.
    MaybePersist(target, speedEst) {
        if Abs(target - speedEst) < 3
            this.LearnedDuty := this.Integral
    }

    ResetHold() {
        this.Integral := 0.4
    }

    ; One control step. Returns {Duty, BrakeDuty} and updates internal state.
    Step(target, speedEst, accelEst, dt) {
        err := target - speedEst
        over := -err

        ; learn the hold-throttle only when near target (frozen while braking/far below)
        if (err > -this.BrakeSoftGap && err < this.FullThrottleGap && dt > 0.01 && dt < 1)
            this.Integral := Min(1, Max(0, this.Integral + this.Ki * err * dt))

        ; --- brake: predict where speed is heading, hold brake until it settles ---
        predicted := speedEst + accelEst * this.BrakeLookahead
        held := A_TickCount - this.BrakeChangeTick

        if (this.BrakeDuty = 0) {
            wayOver := over >= this.BrakeHardGap
            gainingOnHill := over >= this.BrakeSoftGap && accelEst >= this.BrakeAccelThreshold
            if ((wayOver || gainingOnHill) && speedEst > this.MinBrakeSpeed && held > this.MinBrakeHold) {
                this.BrakeDuty := 1
                this.BrakeChangeTick := A_TickCount
            }
        } else {
            closeEnough := predicted <= target + this.BrakeReleaseGap
            settled := over < this.BrakeSoftGap && accelEst <= 0
            if (speedEst <= this.MinBrakeSpeed || (held > this.MinBrakeHold && (closeEnough || settled))) {
                this.BrakeDuty := 0
                this.BrakeChangeTick := A_TickCount
            }
        }

        if (this.BrakeDuty > 0) {
            this.Duty := 0                       ; braking: no throttle
        } else if (err >= this.FullThrottleGap) {
            this.Duty := 1                       ; far below: just hold throttle
        } else if (err <= -3) {
            this.Duty := 0                       ; slightly over: just coast
        } else {
            this.Duty := Min(1, Max(0, this.Integral + this.Kp * err - this.Kd * accelEst))
        }

        if (this.Duty > 0.92)
            this.Duty := 1
        else if (this.Duty < 0.08)
            this.Duty := 0
        if (this.BrakeDuty < 0.08)
            this.BrakeDuty := 0

        return {Duty: this.Duty, BrakeDuty: this.BrakeDuty}
    }
}
