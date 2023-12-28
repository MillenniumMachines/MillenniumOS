; G6500.g: PROBE WORK PIECE - BORE
;
; Meta macro to gather operator input before executing a
; bore probe cycle (G6500.1). The macro will explain to
; the operator what is about to happen and ask for an
; approximate bore diameter. The macro will then ask the
; operator to jog the probe into the center of the bore
; and hit OK, at which point the bore probe cycle will
; be executed.

if { !global.expertMode }
    M291 P"This operation finds the center of a circular bore by probing outwards in 3 directions. You will be asked to enter a bore diameter and jog the touch probe into the bore, below the top surface." R"Probe: BORE" J1 T0 S3
    if { result != 0 }
        abort { "Bore probe aborted!" }

; Prompt for bore diameter
M291 P"Please enter approximate bore diameter. This is used to set our probing distance." R"Probe: BORE" J1 T0 S6 F"6.0"
if { result != 0 }
    abort { "Bore probe aborted!" }
else
    var boreDiameter = { input }
    M291 P"Please jog the probe into the bore, below the top surface and press OK." R"Probe: BORE" X1 Y1 Z1 J1 T0 S3
    if { result != 0 }
        abort { "Bore probe aborted!" }
    else
        ; Run the bore probe cycle
        G6500.1 W{param.W} H{var.boreDiameter} J{move.axes[global.mosIX].machinePosition} K{move.axes[global.mosIY].machinePosition} L{move.axes[global.mosIZ].machinePosition}
