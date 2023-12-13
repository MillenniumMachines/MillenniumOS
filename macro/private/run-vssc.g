; run-vssc.g
; Implements Variable Spindle Speed Control.
; The intention here is to periodically vary the
; spindle speed by a user-configured variance
; above and below the requested spindle speed
; to avoid creating resonances at a constant speed.

if { !exists(global.mosLoaded) || !global.mosLoaded }
    M99

; This file will be run for every loop of daemon.g.

; We need to calculate the time since the previous
; speed variance, and then implement the new variance
; if the correct time has passed.


; If tool is not active, dont bother calculating anything
if { spindles[global.spindleID].state != "forward" }
    M99 ; Return, spindle is not active

; Use uptime to get millisecond precision
var curTime  = { mod(state.upTime, 1000000) * 1000 + state.msUpTime }

; Calculate time elapsed since previous VSSC speed adjustment
var elapsedTime = var.curTime - global.vsscPreviousAdjustmentTime

; This deals with time rollovers if machine is on for more than ~24 days
; see https://forum.duet3d.com/topic/27608/time-measurements/8
if { var.elapsedTime < 0 }
  set var.elapsedTime = var.elapsedTime + 1000000 * 1000

; Check if we need to adjust the spindle speed
if { var.elapsedTime < global.vsscPeriod }
    M99 ; return, not enough time passed for adjustment

; Find the current spindle speed
var curSpindleSpeed = { spindles[global.spindleID].active }

; If spindle speed is zero, return
if { var.curSpindleSpeed == 0 }
    M99 ; return, spindle is off

; Calculate the upper and lower speeds around the previously
; stored base RPM.
var lowerLimit = global.vsscPreviousAdjustmentRPM - global.vsscVariance
var upperLimit = global.vsscPreviousAdjustmentRPM + global.vsscVariance

if { var.upperLimit > global.spindleMaxRPM }
    set var.upperLimit = global.spindleMaxRPM
    set var.lowerLimit = { global.spindleMaxRPM - (2*global.vsscVariance) }
    if { ! global.vsscSpeedWarningIssued }
        echo {"[VSSC]: Cannot increase spindle speed above " ^ global.spindleMaxRPM ^ "! VSSC running between " ^ var.lowerLimit ^ " and " ^ var.upperLimit ^"RPM instead!" }
        set global.vsscSpeedWarningIssued=true

; Fetch the previously stored base RPM
var baseRPM = global.vsscPreviousAdjustmentRPM

; If current RPM is outside of our calculated adjustment limits, then
; store the RPM as our 'new' base, starting adjustment at the next cycle
if { var.upperLimit < var.curSpindleSpeed || var.curSpindleSpeed < var.lowerLimit }
    if { global.vsscDebug }
        echo {"[VSSC] New base spindle RPM detected: " ^ var.curSpindleSpeed }
    set global.vsscSpeedWarningIssued=false
    ; Set the RPM that we're going to adjust over in the next cycle
    set global.vsscPreviousAdjustmentRPM = var.curSpindleSpeed

else
    ; Use the previous adjustment RPM for calculations
    ; Assume previous adjustment direction was negative
    var adjustedSpindleRPM = var.upperLimit

    ; But override if it was positive
    if { global.vsscPreviousAdjustmentDir }
        ; Previous adjustment was positive, so adjust negative
        set var.adjustedSpindleRPM = var.lowerLimit

    ; Update the adjustment direction by negating the boolean
    set global.vsscPreviousAdjustmentDir = !global.vsscPreviousAdjustmentDir

    ; Set adjusted spindle RPM
    if { global.vsscDebug }
        echo {"[VSSC] Adjusted spindle RPM: " ^ var.adjustedSpindleRPM }
    M568 P{global.spindleID} F{ var.adjustedSpindleRPM }

; Update adjustment time
set global.vsscPreviousAdjustmentTime = var.curTime