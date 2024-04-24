; M7.g: MIST COOLANT ON
;
; Enables two pins meant to open solenoids to control pressurized air and liquid coolant
; in a mist configuration. 

; Turn on Air if not already on
M7.1

if { !exists(state.gpOut[1]) }
    abort { "Coolant for mist must be defined in your system config as P1." }

; Turn on Mist Coolant
M42 P1 S1
