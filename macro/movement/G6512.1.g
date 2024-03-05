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

; Make sure we're in the default motion system
M598

if { !exists(param.I) || param.I == null || sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8 }
    abort { "Must provide a valid probe ID (I..)!" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Allow the number of retries to be overridden
var retries = { (exists(param.R) && param.R != null) ? param.R : sensors.probes[param.I].maxProbeCount }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; Make sure machine is stationary before checking machine positions
M400

; Assume current location is start point.
var sP = { move.axes[0].machinePosition, move.axes[1].machinePosition, move.axes[2].machinePosition }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.
var tP = { exists(param.X)? param.X : var.sP[0], exists(param.Y)? param.Y : var.sP[1], exists(param.Z)? param.Z : var.sP[2] }

; Check if the positions are within machine limits
G6515 X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }

; We have to store these, as we apply them manually to
; the probe before triggering a single probe. We must
; be able to access the original values after the probe
; to restore the probe speed after completing each probe.
var roughSpeed   = { sensors.probes[param.I].speeds[0] }
var fineSpeed    = { sensors.probes[param.I].speeds[1] }

var roughDivider = 5

if { var.roughSpeed == var.fineSpeed }
    set var.fineSpeed = { var.roughSpeed / var.roughDivider }
    if { !global.mosExpertMode }
        echo { "MillenniumOS: Probe " ^ param.I ^ " is configured with a single feed rate, which will be used for the initial probe. Subsequent probes will run at " ^ var.fineSpeed ^ "mm/min." }
        echo { "MillenniumOS: Please use M558 K" ^ param.I ^ " F" ^ var.roughSpeed ^ ":" ^ var.fineSpeed ^ " to silence this warning." }

; Set rough probe speed
M558 K{ param.I } F{ var.roughSpeed }

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
    M7500 S{ "Probe " ^ param.I ^ ": Starting probe " ^ iterations+1 ^ "/" ^ var.retries ^ " using G38.2" }
    ; Probe towards surface
    ; NOTE: This has potential to move in all 3 axes!
    G53 G38.2 K{ param.I } X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }
    ; Abort if an error was encountered
    if { result != 0 }
        M7500 S{ "G38.2 reported an error, result=" ^ result }

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
    set var.cP = { move.axes[0].machinePosition, move.axes[1].machinePosition, move.axes[2].machinePosition }

    ; If this is the first probe, set the initial values
    if { iterations == 0 }
        set var.oM = var.cP
        set var.nM = var.cP
        set var.oS = { 0.0, 0.0, 0.0 }
    else
        ; Otherwise calculate mean and cumulative variance for each axis
        set var.nD[0] = { var.cP[0] - var.oM[0] }
        set var.nD[1] = { var.cP[1] - var.oM[1] }
        set var.nD[2] = { var.cP[2] - var.oM[2] }

        set var.nM[0] = { var.oM[0] + (var.nD[0] / iterations) }
        set var.nM[1] = { var.oM[1] + (var.nD[1] / iterations) }
        set var.nM[2] = { var.oM[2] + (var.nD[2] / iterations) }

        set var.nS[0] = { var.oS[0] + (var.nD[0] * (var.cP[0] - var.nM[0])) }
        set var.nS[1] = { var.oS[1] + (var.nD[1] * (var.cP[1] - var.nM[1])) }
        set var.nS[2] = { var.oS[2] + (var.nD[2] * (var.cP[2] - var.nM[2])) }

        ; Set old values for next iteration
        set var.oM = var.nM
        set var.oS = var.nS

        ; TODO: Does this actually calculate per-probe variance accurately?
        ; Calculate per-probe variance on each axis
        if { iterations > 1 }
            set var.pV[0] = { var.nS[0] / (iterations) }
            set var.pV[1] = { var.nS[1] / (iterations) }
            set var.pV[2] = { var.nS[2] / (iterations) }

            M7500 S{ "Probe " ^ iterations ^ " Mean Location: X=" ^ var.nM[0] ^ " Y=" ^ var.nM[1] ^ " Z=" ^ var.nM[2] }
            M7500 S{ "Probe " ^ iterations ^ " Cumulative Variance: X=" ^ var.nS[0] ^ " Y=" ^ var.nS[1] ^ " Z=" ^ var.nS[2] }
            M7500 S{ "Probe " ^ iterations ^ " Variance: X=" ^ var.pV[0] ^ " Y=" ^ var.pV[1] ^ " Z=" ^ var.pV[2] }

    ; Wait for all moves in the queue to finish
    M400

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
    var tR = true
    if { var.tP[0] != var.sP[0] }
        set var.tR = { var.tR && var.pV[0] <= sensors.probes[param.I].tolerance }
    if { var.tP[1] != var.sP[1] }
        set var.tR = { var.tR && var.pV[1] <= sensors.probes[param.I].tolerance }
    if { var.tP[2] != var.sP[2] }
        set var.tR = { var.tR && var.pV[2] <= sensors.probes[param.I].tolerance }

    ; If we're within tolerance on all axes, we can stop probing
    ; and report the result.
    if { var.tR }
        M7500 S{ "Probe " ^ param.I ^ ": Reached requested tolerance " ^ sensors.probes[param.I].tolerance ^ "mm after " ^ iterations+1 ^ "/" ^ var.retries ^ " probes" }
        break

    ; Dwell so machine can settle, if necessary
    if { sensors.probes[param.I].recoveryTime > 0.0 }
        G4 P{ ceil(sensors.probes[param.I].recoveryTime * 1000) }


M7500 S{ "Probe cycle finished, setting vars" }

; Reset probing speed limits
M558 K{ param.I } F{ var.roughSpeed, var.fineSpeed }

; Save output variables. No compensation applied here!
set global.mosProbeCoordinate = { var.nM }
set global.mosProbeVariance = { var.pV }