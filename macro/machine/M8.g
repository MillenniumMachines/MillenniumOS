; M8.g: FLOOD COOLANT ON
;
; Enables a pin meant to turn on a pump to flood the bit with coolant.

if { !exists(state.gpOut[2]) }
    abort { "Flood coolant pump must be defined in your system config as P2." }

; Turn on Flood Coolant
M42 P2 S1
