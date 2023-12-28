; G6510.1.g: SINGLE SURFACE PROBE - EXECUTE
;
; Repeatable surface probe in any direction.
;
; G6510.1
;    I<probe-id>
;    {X,Y,Z}<one-or-more-target-coord>
;    L<start-coord-z>
;    {J,K}<optional-start-coord-xy>
;
; Probes from the given position towards a target position
; until the given probe ID is activated. The probe then resets
; away from the probed surface by a back-off distance in the axes
; it was moving in. It then repeats the probe a number of times
; to generate an average position in all 3 axes.
; It is up to the calling macro to determine which output coordinates
; from this macro should be used (i.e. if probing horizontally, the
; probed Z coordinate is irrelevant).
;
; NOTE: This macro runs in machine co-ordinates, so do not use
; starting or target positions from non-machine co-ordinate systems!
;
; This probing routine can probe in 1, 2 or 3 axes.
;
; All co-ordinates are absolute machine co-ordinates!
; Examples:
;   G6510.1 I1 L{move.axes[2].max} Z{move.axes[2].min} -
;     Probe at current X/Y machine position, Z=max towards
;     Z=min using probe 1. This might be used for probing
;     tool offset using the toolsetter.
;
;   G6510.1 I2 L-10 X100 - Probe from current X/Y machine
;     position at Z=-10 towards X=100 using probe 2.
;     This might be used for probing one side of a workpiece.
;     There would be no movement in the Y or Z directions during
;     the probe movement.
;
;   G6510.1 I2 J50 K50 L-20 X0 Y0 - Probe from X=50, Y=50,
;     Z=-20 towards X=0, Y=0 (2 axis) using probe 2. This
;     would be a diagonal probing move.
;
;   G6510.1 I1 J50 K50 L-10 X0 Y0 Z-20 - Probe from X=50,
;     Y=50, Z=-10 towards X=0, Y=0, Z=-20 (3 axis) using
;     probe 1. This would involve movement in all 3 axes
;     at once. Can't think of where this would be useful right now
;     but it's possible!
;
; This macro is designed to be called directly with parameters set. To gather
; parameters from the user, use the G6510 macro which will prompt the operator
; for the required parameters.

; TODO: Implement probe radius and deflection compensation
;var probeCompensation = { - (global.mosTouchProbeRadius - global.mosTouchProbeDeflection) }

if { !exists(param.I) || sensors.probes[param.I].type != 8 }
    abort { "Must provide a valid probe ID (I..)!" }

; Default to current machine position for unset X/Y starting locations
var sX = { exists(param.J) ? param.J : move.axes[global.mosIX].machinePosition }
var sY = { exists(param.K) ? param.J : move.axes[global.mosIY].machinePosition }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Initial Z height (L...) must be provided by operator as we cannot make safe assumptions
; about where we are probing.
if { !exists(param.L) }
    abort { "Must provide Z height to begin probing at (L..)!" }

var sZ = { param.L }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.
var targetPos = {
    exists(param.X) ? param.X : var.sX,
    exists(param.Y) ? param.Y : var.sY,
    exists(param.Z) ? param.Z : var.sZ
}

; NOTE: We assume the _current_ height of the probe (when macro is called) is safe for lateral moves.
var safeZ = { move.axes[global.mosIZ].machinePosition }

; Probes can be configured with a single probing speed
; or a rough and fine probing speed. If a single speed
; is configured, then we use it as the rough speed
; and divide it by 5 to get the fine speed.
; This is generally a safe default although

var roughSpeed   = sensors.probes[param.I].speeds[0]
var fineSpeed    = sensors.probes[param.I].speeds[1]
var roughDivider = 5

if { var.roughSpeed == var.fineSpeed }
    set var.fineSpeed = var.roughSpeed / var.roughDivider
    if { !global.mosExpertMode }
        echo { "MillenniumOS: Probe " ^ param.I ^ " is configured with a single feed rate, which will be used for the initial probe. Subsequent probes will run at " ^ var.fineSpeed ^ "mm/min." }
        echo { "MillenniumOS: Please use M558 K" ^ param.I ^ " F" ^ var.roughSpeed ^ ":" ^ var.fineSpeed ^ " to silence this warning." }

; 3 retries is the minimum to acquire a valid average.
; If we're within requested tolerance after this many
; retries, we stop probing.
var minProbes   = 3

var roughHeight = sensors.probes[param.I].diveHeights[0]
var fineHeight  = sensors.probes[param.I].diveHeights[1]
var retries     = sensors.probes[param.I].maxProbeCount
var recovery    = sensors.probes[param.I].recoveryTime
var tolerance   = sensors.probes[param.I].tolerance
var travelSpeed = sensors.probes[param.I].travelSpeed



; Calculate a multiplier for the backoff direction
; in each axis.
; This gives us -1, 0 or 1 for each axis which is multiplied
; by the backoff distance to give us the correct backoff direction
; and distance.
var movementAxes = {
    (param.X > var.sX) ? 1 : (param.X < var.sX ? -1 : 0),
    (param.Y > var.sY) ? 1 : (param.Y < var.sY ? -1 : 0),
    (param.Z > var.sZ) ? 1 : (param.Z < var.sZ ? -1 : 0)
}

; Use absolute positions in mm
G90
G21

; TODO: Can we perform all non-probing moves using G38.2 as well?
; This would allow us to move to our starting position
; while also observing the probe status. If we accidentally
; collide with something else on the way to our probing point,
; we can abort the probe and return an error.
; e.g. M558 K{param.I} F{var.travelSpeed}
;      G38.2 K{param.I} Z{var.safeZ}
;      G38.2 K{param.I} X{var.sX} Y{var.sY}

; Set travel speed
G53 G1 F{var.travelSpeed}

; Just confirm we're at safe height in Z
G53 G1 Z{var.safeZ}

; Move to starting position
G53 G1 X{var.sX} Y{var.sY}

; Move down to probe height
G53 G1 Z{var.sZ}

; Set rough probe speed
M558 K{param.I} F{var.roughSpeed}

; These variables are used within the probing loop to calculate
; average positions and variances of the probed points.
; We track position in all 3 axes, as our probing direction may be
; rotated so we are not moving in a single axis.
var curPos      = { 0,0,0 }
var oM          = { 0,0,0 }
var oS          = { 0.0, 0.0, 0.0 }
var nD          = { 0,0,0 }
var nM          = { 0,0,0 }
var nS          = { 0,0,0 }
var variance    = { 0,0,0 }

; Probe until we hit a retry limit.
; We may also abort early if we reach the requested tolerance
while { iterations <= var.retries }
    ; Probe towards surface
    ; NOTE: This has potential to move in all 3 axes!
    G53 G38.2 X{var.targetPos[global.mosIX]} Y{var.targetPos[global.mosIY]} Z{var.targetPos[global.mosIZ]} K{global.mosTouchProbeID}

    ; Abort if an error was encountered
    if { result != 0 }
        ; Reset probing speed limits
        M558 K{param.I} F{var.roughSpeed, var.fineSpeed}

        ; Park. This is a safety precaution to prevent subsequent X/Y moves from
        ; crashing the probe.
        G27
        abort { "MillenniumOS: Probe " ^ param.I ^ " experienced an error, aborting!" }


    ; Drop to fine probing speed
    M558 K{param.I} F{var.fineSpeed}

    ; Record current position into local variable
    set var.curPos = { move.axes[global.mosIX].machinePosition, move.axes[global.mosIY].machinePosition, move.axes[global.mosIZ].machinePosition }

    ; We only start tracking values after the first probe
    if { iterations > 0 }
        ; If this is the first probe, set the initial values
        if { iterations == 1 }
            set var.oM = var.curPos
            set var.nM = var.curPos
            set var.oS = { 0.0, 0.0, 0.0 }
        else
            ; Otherwise calculate mean and cumulative variance for each axis
            set var.nD[global.mosIX] = { var.curPos[global.mosIX] - var.oM[global.mosIX] }
            set var.nD[global.mosIY] = { var.curPos[global.mosIY] - var.oM[global.mosIY] }
            set var.nD[global.mosIZ] = { var.curPos[global.mosIZ] - var.oM[global.mosIZ] }

            set var.nM[global.mosIX] = { var.oM[global.mosIX] + (var.nD[global.mosIX] / iterations) }
            set var.nM[global.mosIY] = { var.oM[global.mosIY] + (var.nD[global.mosIY] / iterations) }
            set var.nM[global.mosIZ] = { var.oM[global.mosIZ] + (var.nD[global.mosIZ] / iterations) }

            set var.nS[global.mosIX] = { var.oS[global.mosIX] + (var.nD[global.mosIX] * (var.curPos[global.mosIX] - var.nM[global.mosIX])) }
            set var.nS[global.mosIY] = { var.oS[global.mosIY] + (var.nD[global.mosIY] * (var.curPos[global.mosIY] - var.nM[global.mosIY])) }
            set var.nS[global.mosIZ] = { var.oS[global.mosIZ] + (var.nD[global.mosIZ] * (var.curPos[global.mosIZ] - var.nM[global.mosIZ])) }

            ; Set old values for next iteration
            set var.oM = var.nM
            set var.oS = var.nS

        ; Calculate per-probe variance on each axis
        set var.variance[global.mosIX] = { var.nS[global.mosIX] / (iterations - 1) }
        set var.variance[global.mosIY] = { var.nS[global.mosIY] / (iterations - 1) }
        set var.variance[global.mosIZ] = { var.nS[global.mosIZ] / (iterations - 1) }


    ; Apply correct back-off distance
    var backoffDist = { iterations == 0 ? var.roughHeight : var.fineHeight }
    ; Move away from the trigger point.

    ; Only back-off in directions where we actually moved
    G53 G1
        X{var.curPos[global.mosIX] + (var.movementAxes[global.mosIX] * var.backoffDist)}
        Y{var.curPos[global.mosIY] + (var.movementAxes[global.mosIY] * var.backoffDist)}
        Z{var.curPos[global.mosIZ] + (var.movementAxes[global.mosIZ] * var.backoffDist)}

    ; If we've reached the requested tolerance and a minimum number of probes, stop probing
    ; TODO: Test if max() actually works on arrays.
    ; If not, we'll need to check each member of variance individually.
    if { max(var.variance) < var.tolerance && iterations >= var.minProbes }
        if { !global.mosExpertMode }
            echo { "MillenniumOS: Probe " ^ param.I ^ ": Reached requested tolerance " ^ var.tolerance ^ "mm after " ^ iterations ^ "/" ^ var.retries ^ " probes" }
        break

    if { var.recovery > 0.0 }
        ; Dwell so machine can settle
        G4 P{ceil(var.recovery*1000)}


; Reset probing speed limits
M558 K{param.I} F{var.roughSpeed, var.fineSpeed}

; Move to safe height
G53 G1 Z{var.safeZ}

; Set probe output variable X, Y and Z
; Only set output variables for axes we actually moved in.
; This means we can chain multiple G6510.1 calls and only
; read the output variables for the axes we're interested in.
if { var.movementAxes[global.mosIX] != 0 }
    set global.mosProbeCoordinate[global.mosIX]=var.nM[global.mosIX]
if { var.movementAxes[global.mosIY] != 0 }
    set global.mosProbeCoordinate[global.mosIY]=var.nM[global.mosIY]
if { var.movementAxes[global.mosIZ] != 0 }
    set global.mosProbeCoordinate[global.mosIZ]=var.nM[global.mosIZ]
