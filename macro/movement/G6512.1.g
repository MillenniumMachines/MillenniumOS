; G6512.1.g: SINGLE SURFACE PROBE - EXECUTE WITH PROBE
;
; Repeatable surface probe in any direction.
;
; NOTE: This macro does very little checking of parameters because it
; is intended to be called from other macros which validate at a higher
; level. If using this macro directly, please check your parameters
; (particularly start and target positions) before calling this macro.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.I) || param.I == null || sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8 }
    abort { "G6512.1: Must provide a valid probe ID (I..)!" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6512.1: Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

if { !exists(global.mosMI) }
    global mosMI = { null }

; Allow the number of retries to be overridden
var retries = { (exists(param.R) && param.R != null) ? param.R : (sensors.probes[param.I].maxProbeCount + 1) }

; Whether to throw an error if the probe is not activated
; when it reaches the target position.
var errors = { !exists(param.E) || param.E != 0 }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; Cancel rotation compensation as we use G53 on the probe move.
; Leaving rotation compensation active causes us to fail position
; checks.
G69

set global.mosPRRT = { var.retries }
set global.mosPRRS = 0

; Get current machine position
M5000 P0

; Set start position based on current position
var sP = { global.mosMI }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.
var tP = { exists(param.X)? param.X : var.sP[0], exists(param.Y)? param.Y : var.sP[1], exists(param.Z)? param.Z : var.sP[2] }

; Check if the positions are within machine limits
M6515 X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }

; We have to store these, as we apply them manually to
; the probe before triggering a single probe. We must
; be able to access the original values after the probe
; to restore the probe speed after completing each probe.
var roughSpeed   = { sensors.probes[param.I].speeds[0] }
var fineSpeed    = { sensors.probes[param.I].speeds[1] }
var curSpeed     = { var.roughSpeed }

var roughDivider = 5

if { var.roughSpeed == var.fineSpeed }
    set var.fineSpeed = { var.roughSpeed / var.roughDivider }
    if { !global.mosEM }
        echo { "MillenniumOS: Probe " ^ param.I ^ " is configured with a single feed rate, which will be used for the initial probe. Subsequent probes will run at " ^ var.fineSpeed ^ "mm/min." }
        echo { "MillenniumOS: Please use M558 K" ^ param.I ^ " F" ^ var.roughSpeed ^ ":" ^ var.fineSpeed ^ " in your config to silence this warning." }

; These variables are used within the probing loop to calculate
; average positions and variances of the probed points.
; We track position in all 3 axes, as our probing direction may be
; rotated so we are not moving in a single axis.
var cP = { vector(3, 0) }
var oM = { vector(3, 0) }
var oS = { vector(3, 0.0) }
var nD = { vector(3, 0) }
var nM = { vector(3, 0) }
var nS = { vector(3, 0) }
var pV = { vector(3, sensors.probes[param.I].tolerance + 10) }

; Probe until we hit a retry limit.
; We may also abort early if we reach the requested tolerance
while { iterations <= var.retries }
    ; Probe towards surface
    ; NOTE: This has potential to move in all 3 axes!

    ; If errors are enabled then use G38.2 which will error
    ; if the probe is not activated by the time we reach the target.
    ; This is not always what we want, so allow specification of E0 to
    ; disable error reporting. This is used for features like tool
    ; offsetting where we don't want to error if the toolsetter is not
    ; activated at one probe point.

    if { var.errors }
        G53 G38.2 K{ param.I } F{ var.curSpeed } X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }
        ; Abort if an error was encountered
        if { result != 0 }

            ; Park at Z max.
            ; This is a safety precaution to prevent subsequent X/Y moves from
            ; crashing the probe.
            G27 Z1

            abort { "G6512.1: Probe " ^ param.I ^ " experienced an error, aborting!" }
    else
        ; Disable errors by using G38.3
        G53 G38.3 K{ param.I } F{ var.curSpeed } X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }

    ; Get current machine position
    M5000 P0

    set var.cP = { global.mosMI }

    ; Set the initial values for iterations 0 and 1.
    ; Separate logic for iteration 0 (high speed) and iteration 1 (first fine speed)
    if { iterations == 0 }
        ; First probe at high speed - just initialize values
        set var.oM = var.cP
        set var.nM = var.cP
        set var.oS = { 0.0, 0.0, 0.0 }
    elif { iterations == 1 }
        ; Second probe at fine speed - reset mean to this more accurate value
        set var.oM = var.cP
        set var.nM = var.cP
        set var.oS = { 0.0, 0.0, 0.0 }
    else
        ; Otherwise calculate mean and cumulative variance for each axis
        ; Store intermediate values to avoid long expressions
        var deltaX = { var.cP[0] - var.oM[0] }
        var deltaY = { var.cP[1] - var.oM[1] }
        var deltaZ = { var.cP[2] - var.oM[2] }

        ; Apply scaling factor based on iteration count
        var scaleFactor = { 1.0 / (iterations-1) }

        ; Calculate new means
        set var.nM[0] = { var.oM[0] + var.deltaX * var.scaleFactor }
        set var.nM[1] = { var.oM[1] + var.deltaY * var.scaleFactor }
        set var.nM[2] = { var.oM[2] + var.deltaZ * var.scaleFactor }

        ; Calculate contribution to sum of squares
        ; Using temporary variables for clarity and shorter lines
        var ssContribX = { var.deltaX * (var.cP[0] - var.nM[0]) }
        var ssContribY = { var.deltaY * (var.cP[1] - var.nM[1]) }
        var ssContribZ = { var.deltaZ * (var.cP[2] - var.nM[2]) }

        ; Update sum of squares - using temporary variables for readability
        set var.nS[0] = { var.oS[0] + var.ssContribX }
        set var.nS[1] = { var.oS[1] + var.ssContribY }
        set var.nS[2] = { var.oS[2] + var.ssContribZ }

        ; Set old values for next iteration
        set var.oM = var.nM
        set var.oS = var.nS

        ; Calculate per-probe variance on each axis
        if { iterations > 1 }
            ; Ensure denominator is valid and variance isn't negative due to numerical errors
            var divisor = { iterations - 1 }

            ; Calculate variance using the accumulated sum of squares
            var varianceX = { var.nS[0] / var.divisor }
            var varianceY = { var.nS[1] / var.divisor }
            var varianceZ = { var.nS[2] / var.divisor }

            ; Ensure variance isn't negative due to calculation errors
            set var.pV[0] = { var.varianceX < 0.0 ? 0.0 : var.varianceX }
            set var.pV[1] = { var.varianceY < 0.0 ? 0.0 : var.varianceY }
            set var.pV[2] = { var.varianceZ < 0.0 ? 0.0 : var.varianceZ }

    ; Drop to fine probing speed
    set var.curSpeed = { var.fineSpeed }

    ; If we have not moved from the starting position, do not back off.
    ; bN will return NaN if the start and current positions are the same
    ; and this will cause unintended behaviour.
    if { var.sP[0] != var.cP[0] || var.sP[1] != var.cP[1] || var.sP[2] != var.cP[2] }

        ; Apply correct back-off distance
        var backoff = { iterations == 0 ? sensors.probes[param.I].diveHeights[0] : sensors.probes[param.I].diveHeights[1] }

        ; Calculate normal
        ; This is the distance between the current and starting position
        ; in a straight line.
        var bN = { sqrt(pow(var.sP[0] - var.cP[0], 2) + pow(var.sP[1] - var.cP[1], 2) + pow(var.sP[2] - var.cP[2], 2)) }

        ; In some cases, our back-off distance might be higher than
        ; the distance we've travelled from the starting location.
        ; In this case, we should travel back to the starting location
        ; instead, because otherwise we risk crashing into things (like
        ; the other side of a bore that we just probed).
        ; If the backoff distance is higher than the normal from from the
        ; starting location, then we use the normal as the backoff distance.
        ; This is essentially the same as multiplying var.d{X,Y,Z} by 1.


        ; Calculate normalized direction and backoff per axis,
        ; and apply to current position.
        var bPX = { var.cP[0] + ((var.sP[0] - var.cP[0]) / var.bN * ((var.backoff > var.bN) ? var.bN : var.backoff)) }
        var bPY = { var.cP[1] + ((var.sP[1] - var.cP[1]) / var.bN * ((var.backoff > var.bN) ? var.bN : var.backoff)) }
        var bPZ = { var.cP[2] + ((var.sP[2] - var.cP[2]) / var.bN * ((var.backoff > var.bN) ? var.bN : var.backoff)) }

        ; This move probably doesn't need to be protected since we
        ; can only move back to the starting location, which is
        ; where we already moved _from_.
        G6550 I{ param.I } X{ var.bPX } Y{ var.bPY } Z{ var.bPZ }

    ; If axis has moved, check if we're within tolerance on that axis.
    ; We can only abort early if we're within tolerance on all moved (probed) axes.
    ; If we're not performing error checking, then we can abort early if the current
    ; position is the same as the target position (i.e. the probe was not activated)
    var tR = { true }
    if { var.tP[0] != var.sP[0] }
        set var.tR = { var.tR && ((var.pV[0] <= sensors.probes[param.I].tolerance && iterations > 2) || (!var.errors && abs(var.cP[0] - var.tP[0]) <= sensors.probes[param.I].tolerance)) }
    if { var.tP[1] != var.sP[1] }
        set var.tR = { var.tR && ((var.pV[1] <= sensors.probes[param.I].tolerance && iterations > 2) || (!var.errors && abs(var.cP[1] - var.tP[1]) <= sensors.probes[param.I].tolerance)) }
    if { var.tP[2] != var.sP[2] }
        set var.tR = { var.tR && ((var.pV[2] <= sensors.probes[param.I].tolerance && iterations > 2) || (!var.errors && abs(var.cP[2] - var.tP[2]) <= sensors.probes[param.I].tolerance)) }

    set global.mosPRRS = { iterations + 1 }

    ; If we're within tolerance on all axes, we can stop probing
    ; and report the result.
    if { var.tR }
        break

    ; Dwell so machine can settle, if necessary
    if { sensors.probes[param.I].recoveryTime > 0.0 }
        G4 P{ ceil(sensors.probes[param.I].recoveryTime * 1000) }

if { !exists(global.mosMI) }
    global mosMI = { null }

; Save output variable.
set global.mosMI = { var.nM }