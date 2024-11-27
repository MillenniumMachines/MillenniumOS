; pause.g - PAUSE CURRENT JOB

; Save pre-pause state of all general purpose
; output pins.
while { iterations < #state.gpOut }
    if { state.gpOut[iterations] != null }
        set global.mosPS[iterations] = state.gpOut[iterations].pwm

; Raise the spindle to the top of the Z axis and
; then stop it, but do not move the table.
G27 Z1