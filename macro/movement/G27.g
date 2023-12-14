; G27.g
; Park spindle, and center the work area in an accessible location.
;
; USAGE: "G27"

; Stop spindle after raising Z, in case it is spinning and
; in contact with the work piece when this macro is called.

; Use absolute positions in mm
G90
G21

; Move spindle to top of Z travel
G53 G0 Z{move.axes[2].max}

; Stop spindle
M5

; Move table to center of X, and front of Y
G53 G0 X{(move.axes[0].max - move.axes[0].min)/2} Y{(move.axes[1].max)/2}
