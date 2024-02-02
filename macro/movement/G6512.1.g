; G6512.1.g: SINGLE SURFACE PROBE - EXECUTE WITH PROBE
;
; Repeatable surface probe in any direction.
;
; NOTE: This macro does very little checking of parameters because it
; is intended to be called from other macros which validate at a higher
; level. If using this macro directly, please check your parameters
; (particularly start and target positions) before calling this macro.

if { !exists(param.I) || param.I == null || sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8 }
    abort { "Must provide a valid probe ID (I..)!" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; Make sure machine is stationary before checking machine positions
M400

; Assume current location is start point.
var sX = { move.axes[0].machinePosition }
var sY = { move.axes[1].machinePosition }
var sZ = { move.axes[2].machinePosition }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.
var tPX = { exists(param.X)? param.X : var.sX }
var tPY = { exists(param.Y)? param.Y : var.sY }
var tPZ = { exists(param.Z)? param.Z : var.sZ }

; Check if the positions are within machine limits
G6515 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

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

var roughBackoff = sensors.probes[param.I].diveHeights[0]
var fineBackoff  = sensors.probes[param.I].diveHeights[1]
var retries      = sensors.probes[param.I].maxProbeCount
var recovery     = sensors.probes[param.I].recoveryTime
var tolerance    = sensors.probes[param.I].tolerance
var travelSpeed  = sensors.probes[param.I].travelSpeed

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
    M7500 S{ "Probe " ^ param.I ^ ": Starting probe " ^ iterations ^ "/" ^ var.retries ^ " using G38.2" }
    ; Probe towards surface
    ; NOTE: This has potential to move in all 3 axes!
    G53 G38.2 K{ param.I } X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }
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

    M7500 S{ "Waiting for probe moves to complete" }

    ; G38 commands appear to return before the machine has finished moving
    ; (likely during deceleration), so we need to wait for the machine to
    ; stop moving entirely before recording the position. There must be a
    ; better way to do this, but I can't work it out at the moment. So
    ; this will suffice. TODO: Fix this.
    G4 P{global.mosProbePositionDelay}

    ; Drop to fine probing speed
    M558 K{ param.I } F{ var.fineSpeed }

    M7500 S{ "Calculating mean position" }

    ; Record current position into local variable
    set var.curPos = { move.axes[0].machinePosition, move.axes[1].machinePosition, move.axes[2].machinePosition }

    ; We only start tracking values after the first probe
    if { iterations > 0 }
        ; If this is the first probe, set the initial values
        if { iterations == 1 }
            set var.oM = var.curPos
            set var.nM = var.curPos
            set var.oS = { 0.0, 0.0, 0.0 }
        else
            ; Otherwise calculate mean and cumulative variance for each axis
            set var.nD[0] = { var.curPos[0] - var.oM[0] }
            set var.nD[1] = { var.curPos[1] - var.oM[1] }
            set var.nD[2] = { var.curPos[2] - var.oM[2] }

            set var.nM[0] = { var.oM[0] + (var.nD[0] / iterations) }
            set var.nM[1] = { var.oM[1] + (var.nD[1] / iterations) }
            set var.nM[2] = { var.oM[2] + (var.nD[2] / iterations) }

            set var.nS[0] = { var.oS[0] + (var.nD[0] * (var.curPos[0] - var.nM[0])) }
            set var.nS[1] = { var.oS[1] + (var.nD[1] * (var.curPos[1] - var.nM[1])) }
            set var.nS[2] = { var.oS[2] + (var.nD[2] * (var.curPos[2] - var.nM[2])) }

            ; Set old values for next iteration
            set var.oM = var.nM
            set var.oS = var.nS

        ; Calculate per-probe variance on each axis
        set var.pV[0] = { var.nS[0] / (iterations - 1) }
        set var.pV[1] = { var.nS[1] / (iterations - 1) }
        set var.pV[2] = { var.nS[2] / (iterations - 1) }

    ; Wait for all moves in the queue to finish
    M400

    M7500 S{ "Applying backoff" }
    ; Apply correct back-off distance
    var backoff = { iterations == 0 ? var.roughBackoff : var.fineBackoff }

    ; Calculate distance between start and current position
    var dX = { var.sX - var.curPos[0] }
    var dY = { var.sY - var.curPos[1] }
    var dZ = { var.sZ - var.curPos[2] }

    ; Calculate back-off normal
    var bN = { sqrt(pow(var.dX, 2) + pow(var.dY, 2) + pow(var.dZ, 2)) }

    ; Calculate normalized backoff direction and apply it to each axis
    var bPX = { var.curPos[0] + (var.dX / var.bN * var.backoff) }
    var bPY = { var.curPos[1] + (var.dY / var.bN * var.backoff) }
    var bPZ = { var.curPos[2] + (var.dZ / var.bN * var.backoff) }

    ; TODO: This assumes that the back-off
    ; distance is always safe, as we're moving back
    ; towards our starting location. If our back-off
    ; distance is higher than the distance we travelled from
    ; the starting location then this assumption does not hold
    ; and we should use a protected move instead.
    G6550 I{ param.I } X{ var.bPX } Y{ var.bPY } Z{ var.bPZ }

    ; If axis has moved, check if we're within tolerance on that axis.
    ; We can only abort early if we're within tolerance on all moved (probed) axes.
    var tR = true
    if { var.tPX != var.sX }
        set var.tR = { var.tR && var.pV[0] <= var.tolerance }
    if { var.tPY != var.sY }
        set var.tR = { var.tR && var.pV[1] <= var.tolerance }
    if { var.tPZ != var.sZ }
        set var.tR = { var.tR && var.pV[2] <= var.tolerance }

    ; If we're within tolerance on all axes, we can stop probing
    ; and report the result.
    if { var.tR && iterations >= var.minProbes }
        M7500 S{ "Probe " ^ param.I ^ ": Reached requested tolerance " ^ var.tolerance ^ "mm after " ^ iterations ^ "/" ^ var.retries ^ " probes" }
        break

    if { var.recovery > 0.0 }
        ; Dwell so machine can settle
        G4 P{ ceil(var.recovery*1000) }


M7500 S{ "Probe cycle finished, setting vars" }

; Reset probing speed limits
M558 K{ param.I } F{ var.roughSpeed, var.fineSpeed }

; Save output variables. No compensation applied here!
set global.mosProbeCoordinate = { var.nM }
set global.mosProbeVariance = { var.pV }