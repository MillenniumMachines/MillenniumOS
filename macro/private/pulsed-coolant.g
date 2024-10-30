if { !exists(global.mosLdd) || !global.mosLdd }
    M99

; Pulsed coolant via daemon is enabled

; Use uptime to get millisecond precision
var curTime  = { mod(state.upTime, 1000000) * 1000 + state.msUpTime }

if { global.mosCPLT == null }
    set global.mosCPLT = { var.curTime }

; Calculate time elapsed since previous pulse
var elapsedTime = { var.curTime - global.mosCPLT }

; This deals with time rollovers if machine is on for more than ~24 days
; see https://forum.duet3d.com/topic/27608/time-measurements/8
if { var.elapsedTime < 0 }
  set var.elapsedTime = var.elapsedTime + 1000000 * 1000

; If elapsed time is greater than the configured
; time between pulses, then toggle the output.
if { var.elapsedTime >= global.mosCPI }
    ; Q setting is unimportant here because we're
    ; turning the port fully on and off.
    M42 P{global.mosCPID} S1.0
    G4 P{global.mosCPD}
    M42 P{global.mosCPID} S0
    set global.mosCPLT = { var.curTime }
    M99