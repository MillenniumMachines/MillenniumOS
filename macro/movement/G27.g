; G27.g
; Park spindle, and move work area to an easily accessible spot for the operator.
;
; USAGE: "G27"

; Stop spindle after raising Z, in case it is spinning and
; in contact with the work piece when this macro is called.

G90                        ; absolute positioning
G21                        ; use MM
G53 G0 Z{move.axes[2].max} ; Move spindle to top of Z travel

M5                         ; Stop spindle

; Move table to center of X and Y
G53 G0 X{(move.axes[0].max - move.axes[0].min)/2} Y{(move.axes[1].max - move.axes[1].min)/2}
