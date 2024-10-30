; pause.g - PAUSE CURRENT JOB

; Save pre-pause state of all general purpose
; output pins.
while { iterations < #state.gpOut }
    set global.mosPS[iterations] = state.gpOut[iterations].pwm

; Pulsed Coolant is a special case when the frequency is low.
; RRF can only handle PWM frequencies of 1Hz or greater. If
; the pulse interval is greater than 1 second, then we need to
; check the daemon variable to see if pulsed coolant is enabled.
if { global.mosCPID != null && global.mosCPI > 1000 }
    set global.mosPS[global.mosCPID] = { global.mosCPDE }

; Raise the spindle to the top of the Z axis and
; then stop it, but do not move the table.
G27 Z1