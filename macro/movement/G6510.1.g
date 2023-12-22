; G6510.1.g: SINGLE SURFACE PROBE - EXECUTE
;
; Repeatable surface probe on one axis and direction.
;
; Probes from the given position towards a target position
; until the given probe ID is activated. The probe then resets
; away from the probed surface by a back-off distance, and
; repeats the probe a number of times to generate an average
; position.

; NOTE: This macro runs in machine co-ordinates, so do not use this with
; co-ordinates from other systems (e.g. G54, G55, etc).

; This probing routing can be used to probe in any 3-axis direction.

; This macro is designed to be called directly with parameters set. To gather
; parameters from the user, use the G6510 macro which will prompt the operator
; for the required parameters.

;var probeCompensation = { - (global.mosTouchProbeRadius - global.mosTouchProbeDeflection) }

if { !exists(param.K) || sensors.probes[param.K].type != 8 }
    abort { "Must provide a valid probe ID (K..)!" }

if { !exists(param.D) || param.D == 0 }
    abort { "Must provide direction and distance (D+-..) you want to probe in!" }

if { !exists(param.J) }
    abort { "Must provide axis number to probe on (J0=X,1=Y,2=Z) !" }

; Default to current machine position for unset X/Y starting locations
var sX = { exists(param.X) ? param.X : move.axes[global.mosIX].machinePosition }
var sY = { exists(param.Y) ? param.Y : move.axes[global.mosIY].machinePosition }

; Z must be provided by operator as we cannot make safe assumptions
; about where we are probing.

if { !exists(param.Z) }
    abort { "Must provide Z height to start probing at (Z..)!" }

var sZ = { param.Z }

; Check if probe direction and distance is the same as the starting position
var xEqual = { param.J == global.mosIX && param.D == var.sX }
var yEqual = { param.J == global.mosIY && param.D == var.sY }
var zEqual = { param.J == global.mosIZ && param.D == var.sZ }
var posEqual = { var.xEqual || var.yEqual || var.zEqual }

if { var.posEqual }
    abort { "Probe direction and distance (D+-..) cannot be the same as the starting position in !" }

var posMoveX = { param.J == global.mosIX && param.D > var.sX }
var posMoveY = { param.J == global.mosIY && param.D > var.sY }
var posMoveZ = { param.J == global.mosIZ && param.D > var.sZ }
var posMove  = { var.posMoveX || var.posMoveY || var.posMoveZ }

; NOTE: We assume the _current_ height of the probe (when macro is called) is safe for lateral moves.
var safeZ = { move.axes[global.mosIZ].machinePosition }

; Probes can be configured with a single probing speed
; or a rough and fine probing speed. If a single speed
; is configured, then we use it as the rough speed
; and divide it by 5 to get the fine speed.
; This is generally a safe default although

var oneSpeed     = false
var roughSpeed   = sensors.probes[param.K].speeds[0]
var fineSpeed    = sensors.probes[param.K].speeds[1]
var roughDivider = 5

if { var.roughSpeed == var.fineSpeed }
    set var.fineSpeed = var.roughSpeed / var.roughDivider
    if { !global.mosExpertMode }
        echo { "MillenniumOS: Probe " ^ param.K ^ " is configured with a single feed rate, which will be used for the initial probe. Subsequent probes will run at " ^ var.fineSpeed ^ "mm/min." }
        echo { "MillenniumOS: Please use M558 K" ^ param.K ^ " F" ^ var.roughSpeed ^ ":" ^ var.fineSpeed ^ " to silence this warning." }

; 3 retries is the minimum to acquire a valid average.
; If we're within requested tolerance after this many
; retries, we stop probing.
var minProbes   = 3

var roughHeight = sensors.probes[param.K].diveHeights[0]
var fineHeight  = sensors.probes[param.K].diveHeights[1]
var retries     = sensors.probes[param.K].maxProbeCount
var recovery    = sensors.probes[param.K].recoveryTime
var tolerance   = sensors.probes[param.K].tolerance
var travelSpeed = sensors.probes[param.K].travelSpeed


; If moving in a positive direction (e.g. towards X-max), we need to
; back off in the negative direction (e.g. towards X-min) before
; subsequent probes. We need to invert the back-off distances.
if { var.posMove }
    set var.roughHeight = -var.roughHeight
    set var.fineHeight  = -var.fineHeight

; Use absolute positions in mm
G90
G21

; Set travel speed
G53 G1 F{var.travelSpeed}

; Just confirm we're at safe height in Z
G53 G1 Z{var.safeZ}

; Move to starting position
G53 G1 X{var.sX} Y{var.sY}

; Move down to probe height
G53 G1 Z{var.sZ}

; Set rough probe speed
M558 K{param.K} F{var.roughSpeed}

; These variables are used within the probing loop to calculate
; average positions and variances of the probed points.
var curPos      = 0
var n           = 0
var oD          = 0
var oM          = 0
var oS          = 0
var nD          = 0
var nM          = 0
var nS          = 0
var variance    = 0

while { iterations <= var.retries }
    G90
    G21

    ; Probe towards surface
    if { param.J == global.mosIX }
        G53 G38.2 X{param.D} K{global.mosTouchProbeID}
    elif { param.J == global.mosIY }
        G53 G38.2 Y{param.D} K{global.mosTouchProbeID}
    elif { param.J == global.mosIZ }
        G53 G38.2 Z{param.D} K{global.mosTouchProbeID}

    ; Abort if an error was encountered
    if { result != 0 }
        ; Reset probing speed limits
        M558 K{param.K} F{var.roughSpeed, var.fineSpeed}
        abort { "MillenniumOS: Probe " ^ param.K ^ " experienced an error, aborting!" }

    ; Drop to fine probing speed
    M558 K{param.K} F{var.fineSpeed}

    ; If this is not the first probe, start tracking values
    if { iterations > 0 }
        ; Record current position of probed axis
        set var.curPos = move.axes[param.J].machinePosition

        ; If this is the first probe, set the initial values
        if { iterations == 1 }
            set var.oM = { var.curPos }
            set var.nM = { var.curPos }
            set var.oS = 0.0
        else
            ; Otherwise calculate mean and cumulative variance
            set var.nM = { var.oM + ((var.curPos - var.oM) / iterations) }
            set var.nS = { var.oS + ((var.curPos - var.oM) * (var.curPos - var.nM)) }
            ; Set old values for next iteration
            set var.oM = { var.nM }
            set var.oS = { var.nS }

        ; Calculate per-probe variance
        set var.variance = { var.nS / (iterations - 1) }

        if { !global.mosExpertMode }
            echo { "MillenniumOS: Probe " ^ param.K ^ ":  " ^ iterations ^ "/" ^ var.retries ^ " avg(" ^ global.mosN[param.J] ^ ")=" ^ var.nM ^ "mm, var(" ^ global.mosN[param.J] ^ ")=" ^ (isnan(var.variance)? 0.0 : var.variance ) ^ "mm" }

    ; Apply correct back-off distance
    var backoffDist = { iterations == 0 ? var.roughHeight : var.fineHeight }

    ; Move away from the trigger point. Use relative moves.
    G91
    G21

    if { param.J == global.mosIX }
        G53 G0 X{var.backoffDist}
    elif { param.J == global.mosIY }
        G53 G0 Y{var.backoffDist}
    elif { param.J == global.mosIZ }
        G53 G0 Z{var.backoffDist}

    ; If we've reached the requested tolerance and a minimum number of probes, stop probing
    if { var.variance < var.tolerance && iterations >= var.minProbes }
        if { !global.mosExpertMode }
            echo { "MillenniumOS: Probe " ^ param.K ^ ": Reached requested tolerance " ^ var.tolerance ^ "mm after " ^ iterations ^ "/" ^ var.retries ^ " probes" }
        break

    if { var.recovery > 0.0 }
        ; Dwell so machine can settle
        G4 P{ceil(var.recovery*1000)}


; Reset probing speed limits
M558 K{param.K} F{var.roughSpeed, var.fineSpeed}

; Absolute moves to find ending position
G90
G21

; Move to safe height
G53 G0 Z{var.safeZ}

; Calculate average position and set probe output variables
set global.mosProbeCoordinate={ var.nM }

echo { "MillenniumOS: Probe " ^ param.K ^ ": " ^ global.mosN[param.J] ^ "=" ^ global.mosProbeCoordinate }