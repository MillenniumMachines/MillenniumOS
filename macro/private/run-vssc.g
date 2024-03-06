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

; If tool is not active, dont bother calculating anything
if { spindles[global.mosSID].state != "forward" }
    M99 ; Return, spindle is not active

; Use uptime to get millisecond precision
var curTime  = { mod(state.upTime, 1000000) * 1000 + state.msUpTime }

; Calculate time elapsed since previous VSSC speed adjustment
var elapsedTime = var.curTime - global.mosVSPT

; This deals with time rollovers if machine is on for more than ~24 days
; see https://forum.duet3d.com/topic/27608/time-measurements/8
if { var.elapsedTime < 0 }
  set var.elapsedTime = var.elapsedTime + 1000000 * 1000

; Check if we need to adjust the spindle speed
if { var.elapsedTime < global.mosVSP }
    M99 ; return, not enough time passed for adjustment

; If spindle speed is zero, return
if { spindles[global.mosSID].active == 0 }
    M99 ; return, spindle is off

; Calculate the upper and lower speeds around the previously
; stored base RPM.
var lowerLimit = global.mosVSPS - global.mosVSV
var upperLimit = global.mosVSPS + global.mosVSV

if { var.upperLimit > spindles[global.mosSID].max }
    set var.upperLimit = spindles[global.mosSID].max
    set var.lowerLimit = { spindles[global.mosSID].max - (2*global.mosVSV) }
    if { ! global.mosVSSW }
        echo {"[VSSC]: Cannot increase spindle speed above " ^ spindles[global.mosSID].max ^ "! VSSC running between " ^ var.lowerLimit ^ " and " ^ var.upperLimit ^"RPM instead!" }
        set global.mosVSSW=true

; Fetch the previously stored base RPM
var baseRPM = global.mosVSPS

; If current RPM is outside of our calculated adjustment limits, then
; store the RPM as our 'new' base, starting adjustment at the next cycle
if { var.upperLimit < spindles[global.mosSID].active || spindles[global.mosSID].active < var.lowerLimit }
    if { global.mosDebug }
        echo {"[VSSC] New base spindle RPM detected: " ^ spindles[global.mosSID].active }
    set global.mosVSSW = false
    ; Set the RPM that we're going to adjust over in the next cycle
    set global.mosVSPS = spindles[global.mosSID].active

else
    ; Use the previous adjustment RPM for calculations
    ; Assume previous adjustment direction was negative
    var adjustedSpindleRPM = var.upperLimit

    ; But override if it was positive
    if { global.mosVSPD }
        ; Previous adjustment was positive, so adjust negative
        set var.adjustedSpindleRPM = var.lowerLimit

    ; Update the adjustment direction by negating the boolean
    set global.mosVSPD = !global.mosVSPD

    ; Set adjusted spindle RPM
    if { global.mosDebug }
        echo {"[VSSC] Adjusted spindle RPM: " ^ var.adjustedSpindleRPM }
    M568 F{ var.adjustedSpindleRPM }

; Update adjustment time
set global.mosVSPT = var.curTime