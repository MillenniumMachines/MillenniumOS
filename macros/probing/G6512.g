; G6512.g: SINGLE-AXIS PROBING
;
; Performs a single-axis probe move with compensation and averaging.
;
; USAGE: G6512 [X<pos>|Y<pos>|Z<pos>|A<pos>] I<probeID> [F<speed>] [R<retries>]
;
; Parameters:
;   X|Y|Z|A: Exactly ONE axis parameter must be provided, specifying the target coordinate.
;   I:       Probe ID (e.g., global.nxtTouchProbeID or global.nxtToolSetterID)
;   F:       Optional speed override in mm/min. If not provided, uses probe's configured speeds.
;   R:       Number of retries for averaging (default: probe.maxProbeCount + 1)

; --- Parameter Validation ---

var axisParams = { param.X, param.Y, param.Z, param.A }
var probeAxisIndex = -1

; Set probeAxisIndex and ensure exactly one axis parameter is provided
while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        if { var.probeAxisIndex != -1 }
            abort { "G6512: Exactly one of X, Y, Z, or A must be specified"}
        set var.probeAxisIndex = { iterations }

; Validate probe ID and type
if { !exists(param.I) || param.I == null || param.I < 0 || sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8 }
    abort { "G6512: Invalid probe ID I" }

; Determine number of retries
var retries = { exists(param.R) ? param.R : (sensors.probes[param.I].maxProbeCount + 1) }

G90 G21 G94 ; Use absolute positions in mm

; Get current tool-compensated machine position for all axes
M5000

; Build target vector: copy current positions and override the probed axis
var targetVector = { global.nxtAbsPos }

set var.targetVector[0] = { exists(param.X) ? param.X : var.targetVector[0] }
set var.targetVector[1] = { exists(param.Y) ? param.Y : var.targetVector[1] }
set var.targetVector[2] = { exists(param.Z) ? param.Z : var.targetVector[2] }
set var.targetVector[3] = { exists(param.A) ? param.A : var.targetVector[3] }


; Validate target against machine limits
M6515 X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]} A{var.targetVector[3]}

; Get probe speeds
var roughSpeed = { exists(param.F) ? param.F : sensors.probes[param.I].speeds[0] }
var fineSpeed = { exists(param.F) ? param.F : sensors.probes[param.I].speeds[1] }

if { var.roughSpeed == var.fineSpeed && !exists(param.F) }
    set var.fineSpeed = { var.roughSpeed / 5 }

; --- Probing Loop ---
var sum = 0.0
var count = 0
var speed = var.roughSpeed

var probeDeflectionUm { global.nxtProbeDeflection * 1000 }
var probeTipRadiusUm { global.nxtProbeTipRadius * 1000 }

while { iterations < var.retries }
    ; Refresh current machine position before each probe move
    M5000

    var startPos = global.nxtAbsPos

    ; Execute probe move
    G53 G38.2 K{param.I} F{var.speed} X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]} A{var.targetVector[3]}

    if { result != 0 }
        abort "G6512: Probe failed to trigger"

    ; Get the triggered position
    M5000

    var triggeredPos = global.nxtAbsPos[var.probeAxisIndex]
    var direction = { var.targetCoord > var.startPos ? 1 : -1 }
    var compensated = { var.triggeredPos * 1000 - var.probeDeflectionUm }

    if { var.probeAxisIndex != 2 }
        set var.compensated = { var.compensated + (var.probeTipRadiusUm * var.direction) }

    set var.sum = { var.sum + var.compensated }
    set var.count = { var.count + 1 }

    var backoffDistance = { iterations == 0 ? sensors.probes[param.I].diveHeights[0] : sensors.probes[param.I].diveHeights[1] }
    var backoffTarget = { var.triggeredPos - (var.direction * var.backoffDistance) }

    set var.speed = { var.fineSpeed }

    ; Build backoff vector
    var backoffVector = { global.nxtAbsPos }
    while { #var.backoffVector < 4 }
        set var.backoffVector[#var.backoffVector] = 0
    set var.backoffVector[var.probeAxisIndex] = var.backoffTarget

    ; Backoff move
    G53 G0 X{var.backoffVector[0]} Y{var.backoffVector[1]} Z{var.backoffVector[2]} A{var.backoffVector[3]}

    if { sensors.probes[param.I].recoveryTime > 0 }
        G4 P{ ceil(sensors.probes[param.I].recoveryTime * 1000) }

; --- Finalize ---
set global.nxtLastProbeResult = { round(var.sum / var.count) / 1000 }

echo "G6512: Compensated probe result for axis " ^ move.axes[var.probeAxisIndex].letter ^ ": " ^ global.nxtLastProbeResult
