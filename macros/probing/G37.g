; G37.g: SINGLE-AXIS PROBING
;
; Performs a single-axis probe move with compensation for probe tip radius and deflection.
;
; USAGE: G37 [X<coord>] [Y<coord>] [Z<coord>] [F<feedrate>] [S<axis>]
;
; Parameters:
;   X, Y, Z: Target coordinate for the axis to probe
;   F: Probing feedrate (mm/min)
;   S: Axis to probe (1=X, 2=Y, 3=Z) - if not specified, inferred from coordinate parameter

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Determine which axis to probe
var probeAxis = null
var targetCoord = null

if { exists(param.X) }
    set var.probeAxis = 0  ; X axis
    set var.targetCoord = param.X
elif { exists(param.Y) }
    set var.probeAxis = 1  ; Y axis
    set var.targetCoord = param.Y
elif { exists(param.Z) }
    set var.probeAxis = 2  ; Z axis
    set var.targetCoord = param.Z
elif { exists(param.S) }
    set var.probeAxis = param.S - 1  ; S=1 for X, 2 for Y, 3 for Z
    ; For S parameter, targetCoord must be provided separately? Wait, adjust.

; If S is provided, use it, but coordinate must be in the axis param
; For simplicity, require the coordinate param for the axis.

if { var.probeAxis == null }
    abort "G37: No axis specified. Use X, Y, or Z parameter."

; Validate probe is configured
if { global.nxtProbeToolID == null || global.nxtProbeToolID != state.currentTool }
    abort "G37: Touch probe not configured or not active tool."

; Set feedrate
var feedrate = { exists(param.F) ? param.F : 100 }  ; Default 100 mm/min

; Perform the probe move using G31 (RRF probe command)
; G31 moves until probe triggers, then sets coordinates

; Assume we're probing towards the target
; For compensation, we need to know direction

; Simple implementation: use G31 to target, then compensate the result

; G31 X{var.targetCoord} F{var.feedrate}  ; But G31 syntax is G31 Pnnn Xnnn Ynnn Znnn Fnnn

; In RRF, G31 is probe at point, but for single axis, we can do G31 with one coordinate.

; To probe in +X direction to X=10: G31 X10 F100

; The result is stored in probeTriggerHeight, etc.

; But for compensation:

; After probing, the triggered position is in move.probeTriggerHeight[axis]

; Then apply compensation.

; For tip radius: if axis is 0 or 1 (X or Y), adjust by +/- radius based on direction.

; Direction: if target > current, positive direction.

; For deflection: add to the coordinate (assuming deflection makes it read higher)

; Then, the compensated coordinate is the result.

; But what to do with it? For the core macro, perhaps just echo it or set a variable.

; For cycles, they will use this and log to table.

; For now, let's implement basic probing with compensation.

; First, perform the probe
if { var.probeAxis == 0 }
    G31 X{var.targetCoord} F{var.feedrate}
elif { var.probeAxis == 1 }
    G31 Y{var.targetCoord} F{var.feedrate}
elif { var.probeAxis == 2 }
    G31 Z{var.targetCoord} F{var.feedrate}

; Check if probe triggered
if { !move.probeTriggered }
    abort "G37: Probe did not trigger during move."

; Get the triggered coordinate
var triggeredCoord = move.probeTriggerHeight[var.probeAxis]

; Apply compensation

; Probe deflection: assume it makes the reading higher, so subtract
if { global.nxtProbeDeflection != null }
    set var.triggeredCoord = var.triggeredCoord - global.nxtProbeDeflection

; Probe tip radius: for X/Y, adjust based on direction
if { var.probeAxis < 2 && global.nxtProbeTipRadius != null }
    ; Determine direction: if target > current position, positive direction
    var currentPos = move.axes[var.probeAxis].userPosition
    var direction = { var.targetCoord > currentPos ? 1 : -1 }
    set var.triggeredCoord = var.triggeredCoord + (global.nxtProbeTipRadius * direction)

; The compensated coordinate
echo "G37: Compensated probe result for axis " ^ (var.probeAxis + 1) ^ ": " ^ var.triggeredCoord

; For now, set a global variable for the result
global nxtLastProbeResult = var.triggeredCoord