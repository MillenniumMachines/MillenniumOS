; G27.g: PARK
;
; Park spindle, and center the work area in an accessible location.
;
; USAGE: "G27"

; Stop spindle after raising Z, in case it is spinning and
; in contact with the workpiece when this macro is called.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Use absolute positions in mm
G90
G21
G94

; Move spindle to top of Z travel
G53 G0 Z{move.axes[2].max}

; Stop spindle and wait
M98 P"M5.9.g"

; If park is called with Z parameter, then the table itself will not be
; moved.
if { !exists(param.Z) }
    ; Move table to center of X, and front of Y
    G53 G0 X{(move.axes[0].max - move.axes[0].min)/2} Y{move.axes[1].max}
