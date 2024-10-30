; M7.2.g: PULSED COOLANT ON
;
; Enables daemon controlled coolant pulsing.
; This can be used to inject coolant into
; the air stream at a predefined rate rather
; than simply turning it on or off.

if { !global.mosFeatCoolantControl || global.mosCPID == null }
    echo { "MillenniumOS: Coolant Control feature is disabled or Pulsed Coolant not configured, cannot enable." }
    M99

; Wait for all movement to stop before continuing.
M400


if { global.mosCAID != null }
    ; Turn on air blast first, if configured
    M7.1

; If coolant pulse frequency is 1Hz or more, then
; we can use M950 to set the PWM frequency on the
; port, and then set the duty cycle using M42 to
; enable the port itself. Otherwise, we have to
; use daemon.g to control the port manually.
if { global.mosCPI <= 1000 }
    M950 P{global.mosCPID} Q{ceil(1000/global.mosCPI)}
    M42 P{global.mosCPID} S{ global.mosCPD / global.mosCPI }
    set global.mosCPDE = { false }
else
    ; Enable pulsed coolant via daemon.g
    set global.mosCPDE = { true }