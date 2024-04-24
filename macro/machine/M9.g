; M9.g: ALL COOLANTS OFF
;
; Disables all possible Coolant Outputs.

if { exists(state.gpOut[0]) }
    M42 P0 S0
if { exists(state.gpOut[1]) }
    M42 P1 S0
if { exists(state.gpOut[2]) }
    M42 P2 S0
