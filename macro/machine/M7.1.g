; M7.1.g: AIRBLAST ON
;
; Enables a pin meant to open a solenoid to control pressurized air. 

if { !exists(state.gpOut[0]) }
    abort { "Air must be defined in your system config as P0." }

M42 P0 S1
