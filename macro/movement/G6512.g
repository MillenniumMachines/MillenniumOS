; G6512.g: SINGLE SURFACE PROBE - EXECUTE
;
; Repeatable surface probe in any direction.
;
; G6512
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
;   G6512 I1 L{move.axes[2].max} Z{move.axes[2].min} -
;     Probe at current X/Y machine position, Z=max towards
;     Z=min using probe 1. This might be used for probing
;     tool offset using the toolsetter.
;
;   G6512 I2 L-10 X100 - Probe from current X/Y machine
;     position at Z=-10 towards X=100 using probe 2.
;     This might be used for probing one side of a workpiece.
;     There would be no movement in the Y or Z directions during
;     the probe movement.
;
;   G6512 I2 J50 K50 L-20 X0 Y0 - Probe from X=50, Y=50,
;     Z=-20 towards X=0, Y=0 (2 axis) using probe 2. This
;     would be a diagonal probing move.
;
;   G6512 I1 J50 K50 L-10 X0 Y0 Z-20 - Probe from X=50,
;     Y=50, Z=-10 towards X=0, Y=0, Z=-20 (3 axis) using
;     probe 1. This would involve movement in all 3 axes
;     at once. Can't think of where this would be useful right now
;     but it's possible!
;
; This macro is designed to be called directly with parameters set. To gather
; parameters from the user, use the G6510 macro which will prompt the operator
; for the required parameters.

if { !exists(param.I) || sensors.probes[param.I].type != 8 }
    abort { "Must provide a valid probe ID (I..)!" }

; Make sure machine is stationary before checking machine positions
M400

; Default to current machine position for unset X/Y starting locations
var sX = { (exists(param.J)) ? param.J : move.axes[global.mosIX].machinePosition }
var sY = { (exists(param.K)) ? param.K : move.axes[global.mosIY].machinePosition }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Initial Z height (L...) must be provided by operator as we cannot make safe assumptions
; about where we are probing.
if { !exists(param.L) }
    abort { "Must provide Z height to begin probing at (L..)!" }

; If D is passed, we will not return to safe height after probing.
; This is useful for chaining multiple probing moves at the same
; Z-height together, for example when probing a bore.
var dangerWillRobinson = { exists(param.D) ? true : false }

var sZ = { param.L }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.

var tPX = { exists(param.X)? param.X : var.sX }
var tPY = { exists(param.Y)? param.Y : var.sY }
var tPZ = { exists(param.Z)? param.Z : var.sZ }


; Round start positions
set var.sX = { ceil(var.sX * 1000) / 1000 }
set var.sY = { ceil(var.sY * 1000) / 1000 }
set var.sZ = { ceil(var.sZ * 1000) / 1000 }

; Round target positions
set var.tPX = { ceil(var.tPX * 1000) / 1000 }
set var.tPY = { ceil(var.tPY * 1000) / 1000 }
set var.tPZ = { ceil(var.tPZ * 1000) / 1000 }

; Check if target position is within machine limits
var mLX = { var.tPX < move.axes[global.mosIX].min || var.tPX > move.axes[global.mosIX].max }
var mLY = { var.tPY < move.axes[global.mosIY].min || var.tPY > move.axes[global.mosIY].max }
var mLZ = { var.tPZ < move.axes[global.mosIZ].min || var.tPZ > move.axes[global.mosIZ].max }

; Check if target position is within machine limits
if { var.mLX || var.mLY || var.mLZ }
    abort { "Target probe position is outside machine limits. Reduce overtravel if probing away, or clearance if probing towards, the center of the table" }

; NOTE: We assume the _current_ height of the probe (when macro is called) is safe for lateral moves.
var safeZ = { move.axes[global.mosIZ].machinePosition }

; Probes can be configured with a single probing speed
; or a rough and fine probing speed. If a single speed
; is configured, then we use it as the rough speed
; and divide it by 5 to get the fine speed.
; This is generally a safe default although

var roughSpeed   = { sensors.probes[param.I].speeds[0] }
var fineSpeed    = { sensors.probes[param.I].speeds[1] }
var roughDivider = 5

if { var.roughSpeed == var.fineSpeed }
    set var.fineSpeed = { var.roughSpeed / var.roughDivider }
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
var movementX = { (var.tPX > var.sX) ? -1 : (var.tPX < var.sX ? 1 : 0) }
var movementY = { (var.tPY > var.sY) ? -1 : (var.tPY < var.sY ? 1 : 0) }
var movementZ = { (var.tPZ > var.sZ) ? -1 : (var.tPZ < var.sZ ? 1 : 0) }

; Use absolute positions in mm
G90
G21

; Use protected moves to approach start position

; If starting probe height is above safe height (current Z),
; then move to the starting probe height first.
if { var.sZ > var.safeZ }
    G6550.1 I{ param.I } Z{ var.sZ }

; Move to starting position
G6550.1 I{ param.I } X{ var.sX } Y{ var.sY }

; Move to probe height.
; No-op if we already moved above.
G6550.1 I{ param.I } Z{ var.sZ }

; Set rough probe speed
M558 K{ param.I } F{ var.roughSpeed }

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
var pV          = { 0,0,0 }

; Probe until we hit a retry limit.
; We may also abort early if we reach the requested tolerance
while { iterations <= var.retries }
    ; Probe towards surface
    ; NOTE: This has potential to move in all 3 axes!
    G53 G38.2 K{ param.I } X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

    ; Abort if an error was encountered
    if { result != 0 }
        ; Reset probing speed limits
        M558 K{ param.I } F{ var.roughSpeed, var.fineSpeed }

        ; Park at Z max.
        ; This is a safety precaution to prevent subsequent X/Y moves from
        ; crashing the probe.
        G27 Z1
        abort { "MillenniumOS: Probe " ^ param.I ^ " experienced an error, aborting!" }

    ; Wait for all moves in the queue to finish
    M400

    ; G38 commands appear to return before the machine has finished moving
    ; (likely during deceleration), so we need to wait for the machine to
    ; stop moving entirely before recording the position. There must be a
    ; better way to do this, but I can't work it out at the moment. So
    ; this will suffice. TODO: Fix this.
    G4 P{global.mosProbePositionDelay}

    ; Drop to fine probing speed
    M558 K{ param.I } F{ var.fineSpeed }

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
        set var.pV[global.mosIX] = { var.nS[global.mosIX] / (iterations - 1) }
        set var.pV[global.mosIY] = { var.nS[global.mosIY] / (iterations - 1) }
        set var.pV[global.mosIZ] = { var.nS[global.mosIZ] / (iterations - 1) }


    ; Apply correct back-off distance
    var backoffDist = { iterations == 0 ? var.roughHeight : var.fineHeight }

    ; Calculate distance between start and current position
    var dX = { var.sX - var.curPos[global.mosIX] }
    var dY = { var.sY - var.curPos[global.mosIY] }
    var dZ = { var.sZ - var.curPos[global.mosIZ] }

    ; Calculate back-off normal
    var bN = { sqrt(pow(var.dX, 2) + pow(var.dY, 2) + pow(var.dZ, 2)) }

    ; Calculate normalized direction and backoff
    var backoffX = { var.dX / var.bN * var.backoffDist }
    var backoffY = { var.dY / var.bN * var.backoffDist }
    var backoffZ = { var.dZ / var.bN * var.backoffDist }

    ; Unprotected back-off move.
    ; TODO: This assumes that the back-off
    ; distance is always safe, as we're moving back
    ; towards our starting location. If our back-off
    ; distance is higher than the distance we travelled from
    ; the starting location then this assumption does not hold
    ; and we should use a protected move instead.
    G53 G1 X{ var.curPos[global.mosIX] + var.backoffX } Y{ var.curPos[global.mosIY] + var.backoffY } Z{ var.curPos[global.mosIZ] + var.backoffZ } F{var.travelSpeed}

    ; Wait for all moves in the queue to finish
    M400

    ; Back off until the probe is no longer triggered
    ; G6550.2 I{ param.I } X{ var.curPos[global.mosIX] + var.backoffX } Y{ var.curPos[global.mosIY] + var.backoffY } Z{ var.curPos[global.mosIZ] + var.backoffZ }

    ; Protected move back to the back-off position
    ; G6550.1 I{ param.I } X{ var.curPos[global.mosIX] + var.backoffX } Y{ var.curPos[global.mosIY] + var.backoffY } Z{ var.curPos[global.mosIZ] + var.backoffZ }

    ; If axis has moved, check if we're within tolerance on that axis.
    ; We can only abort early if we're within tolerance on all moved (probed) axes.
    var tR = true
    if { var.movementX != 0 }
        set var.tR = { var.tR && var.pV[global.mosIX] <= var.tolerance }
    if { var.movementY != 0 }
        set var.tR = { var.tR && var.pV[global.mosIY] <= var.tolerance }
    if { var.movementZ != 0 }
        set var.tR = { var.tR && var.pV[global.mosIZ] <= var.tolerance }

    ; If we're within tolerance on all axes, we can stop probing
    ; and report the result.
    if { var.tR && iterations >= var.minProbes }
        if { !global.mosDebug }
            echo { "MillenniumOS: Probe " ^ param.I ^ ": Reached requested tolerance " ^ var.tolerance ^ "mm after " ^ iterations ^ "/" ^ var.retries ^ " probes" }
        break

    if { var.recovery > 0.0 }
        ; Dwell so machine can settle
        G4 P{ ceil(var.recovery*1000) }


; Reset probing speed limits
M558 K{ param.I } F{ var.roughSpeed, var.fineSpeed }

; Move to safe height
; If probing move is called with D parameter,
; we stay at the same height. This allows other
; macros to chain multiple probing moves together
if { ! var.dangerWillRobinson }
    G6550.1 I{ param.I } Z{ var.safeZ }

; Set probe output variable X, Y and Z
; We round to 3 decimal places (0.001mm) which is
; way more than we actually need, because 1.8 degree
; steppers with 8mm leadscrews aren't that accurate
; anyway.
; We compensate for the probe radius and deflection
; here, so the output should be as close to accurate
; as we can achieve, given well calibrated values of
; probe radius and deflection.

; Deflection is subtracted from radius because the
; probe tip will deflect slightly 'backwards' when
; it contacts the surface.
var probeCompensationRadius = { global.mosTouchProbeRadius - global.mosTouchProbeDeflection }

; Calculate the direction of the probe movement
var pdX = { var.nM[global.mosIX] - var.sX }
var pdY = { var.nM[global.mosIY] - var.sY }

; Calculate the magnitude of the direction vector
var mag = { sqrt(pow(var.pdX, 2) + pow(var.pdY, 2)) }

; Normalize the direction vector
var pnX = { var.pdX / var.mag }
var pnY = { var.pdY / var.mag }

; Adjust the final position along the direction of movement in X and Y by the probe compensation radius
set global.mosProbeCoordinate[global.mosIX] = { ceil((var.nM[global.mosIX] + var.probeCompensationRadius * var.pnX) * 1000) / 1000 }
set global.mosProbeCoordinate[global.mosIY] = { ceil((var.nM[global.mosIY] + var.probeCompensationRadius * var.pnY) * 1000) / 1000 }

; We do not compensate for the probe location in Z.
set global.mosProbeCoordinate[global.mosIZ] = { ceil(var.nM[global.mosIZ]*1000) / 1000 }

; This does bring up an interesting conundrum though. If you're probing in 2 axes where
; one is Z, then you have no way of knowing whether the probe was triggered by the Z
; movement or the X/Y movement. If the probe is triggered by Z then we would end up
; compensating on the X/Y axes which would not necessarily be correct.

; For these purposes, we have to assume that it is most likely for probes to be run
; in X/Y, _or_ Z, and we have some control over this as we're writing the higher
; level macros.


set global.mosProbeVariance = { var.pV }