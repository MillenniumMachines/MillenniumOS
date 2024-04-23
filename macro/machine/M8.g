; M8.g: FLOOD COOLANT ON
;
; description

if { !exists(state.gpOut[2]) }
    abort { "Flood coolant pump must be defined in your system config as P2." }

; Turn on Flood Coolant
M42 P2 S1
