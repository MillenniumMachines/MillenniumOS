; G27.g: PARK
;
; Park spindle, and center the work area in an accessible location.
;
; USAGE: G27

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Use absolute positions in mm
G90
G21
G94

; Turn off all coolant outputs
M9

; Move spindle to top of Z travel
if { move.axes[2].homed }
    G53 G0 Z{move.axes[2].max}

; Wait for movement to stop
M400

; Stop spindle and wait
M5.9

; If park is called with Z parameter, then the table itself will not be
; moved.
if { !exists(param.Z) && move.axes[0].homed && move.axes[1].homed }
    ; Move table to center of X, and front of Y
    G53 G0 X{(move.axes[0].max - move.axes[0].min)/2} Y{move.axes[1].max}

; Wait for movement to stop
M400