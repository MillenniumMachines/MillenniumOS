; run-vssc.g
; Implements Variable Spindle Speed Control.
; The intention here is to periodically vary the
; spindle speed by a user-configured variance
; above and below the requested spindle speed
; to avoid creating resonances at a constant speed.

if { !exists(global.mosLdd) || !global.mosLdd }
    M99

; This file will be run for every loop of daemon.g.

; We need to calculate the time since the previous
; speed variance, and then implement the new variance
; if the correct time has passed.

; If spindle is not active or speed is zero, return
if { (spindles[global.mosSID].state != "forward" && spindles[global.mosSID].state != "reverse") || spindles[global.mosSID].active == 0 }
    M99 ; Return, spindle is not active or stationary

; Use uptime to get millisecond precision
var curTime  = { mod(state.upTime, 1000000) * 1000 + state.msUpTime }

; Calculate time elapsed since previous VSSC speed adjustment
var elapsedTime = { var.curTime - global.mosVSPT }

; This deals with time rollovers if machine is on for more than ~24 days
; see https://forum.duet3d.com/topic/27608/time-measurements/8
if { var.elapsedTime < 0 }
  set var.elapsedTime = var.elapsedTime + 1000000 * 1000

; The lower limit is the previously stored speed minus
; half the configured variance, or the maximum spindle speed
; minus the variance, whichever is lower - as we
; don't want to exceed the maximum spindle speed.
var lowerLimit = { min((spindles[global.mosSID].max - global.mosVSV), global.mosVSPS - global.mosVSV/2) }

; But it also needs to be higher than the minimum spindle speed.
set var.lowerLimit = { max(var.lowerLimit, spindles[global.mosSID].min) }

; If current RPM is outside of our adjustment limits, then store the new
; base RPM.
if { spindles[global.mosSID].active < var.lowerLimit || spindles[global.mosSID].active > (var.lowerLimit + global.mosVSV ) }
    if { global.mosDebug }
        echo {"[VSSC] New base spindle RPM detected: " ^ spindles[global.mosSID].active }
    ; Set the RPM that we're going to adjust over in the next cycle
    set global.mosVSPS = spindles[global.mosSID].active

    ; Reset elapsedTime
    set global.mosVSPT = var.curTime
else

    ; Create a sinusoidal adjustment to the spindle speed based on the elapsed
    ; time since the last adjustment.
    var adjustedSpindleRPM = { ceil(var.lowerLimit + global.mosVSV * ((sin(2 * pi * var.elapsedTime / global.mosVSP) + 1) / 2)) }

    if { state.currentTool >= 0 }
        ; Set adjusted spindle RPM
        if { global.mosDebug }
            echo {"[VSSC] Adjusted spindle RPM: " ^ var.adjustedSpindleRPM }
        M568 F{ var.adjustedSpindleRPM }