; G6510.g: SINGLE SURFACE PROBE
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

var axis   = null ; J - Axis to probe on
var target = null ; D - Target position to probe towards
var startX = null ; X - Starting X position
var startY = null ; Y - Starting Y position
var startZ = null ; Z - Starting Z position


if { !exists(param.D) || param.D == 0 }
    abort { "Must provide direction and distance (D+-..) you want to probe in!" }

if { !exists(param.J) }
    abort { "Must provide axis number to probe on (J{" ^ global.mosIX ^ "=" ^ global.mosNX ^ "," ^ global.mosIY ^ "=" ^ global.mosNY ^ "," ^ global.mosIZ ^ "=" ^ global.mosNZ ^"})!" }

; Default to current machine position for unset X/Y starting locations
var sX = param.X ? param.X : move.axes[global.mosIX].machinePosition
var sY = param.Y ? param.Y : move.axes[global.mosIY].machinePosition

; Z must be provided by operator as we cannot make safe assumptions
; about where we are probing.

if { !exists(param.Z) }
    abort { "Must provide Z height to start probing at (Z..)!" }

var sZ = param.Z

; NOTE: We assume the _current_ height of the probe (when macro is called) is safe for lateral moves.
var safeZ = move.axes[global.mosIZ].machinePosition

; Check if probe direction and distance is the same as the starting position
var xEqual = { param.J == global.mosIX && param.D == var.sX }
var yEqual = { param.J == global.mosIY && param.D == var.sY }
var zEqual = { param.J == global.mosIZ && param.D == var.sZ }
var negMoveX = { param.J == global.mosIX && param.D < var.sX }
var negMoveY = { param.J == global.mosIY && param.D < var.sY }
var negMoveZ = { param.J == global.mosIZ && param.D < var.sZ }

if { xEqual || yEqual || zEqual}
    abort { "Probe direction and distance (D+-..) cannot be the same as the starting position in !" }

; Use absolute positions in mm
G90
G21

; Just confirm we're at safe height in Z
G53 G0 Z{var.safeZ}

; Move to starting position
G53 G0 X{var.sX} Y{var.sY}

; Move down to probe height
G53 G0 Z{var.sZ}

; Back to relative moves for probing
G91

; If moving in a negative direction, back off in positive direction
; Compensate for probe width in positive (when probe touches
; surface, it is at an X co-ordinate LESS than where the actual
; surface is, by the radius of the probe).
if { negMoveX || negMoveY || negMoveZ }
    set var.backoffPos        = var.backoffPos
    set var.probeCompensation = { abs(var.probeCompensation) }

while { var.retries <= global.mosTouchProbeNumProbes }
    ; Probe towards surface
    if { param.J == global.mosIX }
        G53 G38.2 X{param.D} K{global.mosTouchProbeID}
    elif { param.J == global.mosIY }
        G53 G38.2 Y{param.D} K{global.mosTouchProbeID}
    elif { param.J == global.mosIZ }
        G53 G38.2 Z{param.D} K{global.mosTouchProbeID}

    ; Abort if an error was encountered
    if { result != 0 }
        ; Reset all speed limits after probe
        M98 P"speed.g"
        abort { "Probe experienced an error, aborting!" }

    ; Record current position
    set var.curPos = move.axes[0].machinePosition

    ; Increase Z speed for backing off
    ; Reduce acceleration
    M203 X{global.mosTouchProbeRoughSpeed}
    M201 X{global.mosMaxAccelLimitX/2}

    ; Move away from the trigger point
    G53 G0 X{var.backoffPos}

    ; If this is not the initial rough probe, record the position
    if var.retries > 0
        ; Add probe position for averaging
        set var.probePos = var.probePos+var.curPos

        M118 P0 L2 S{"Touch Probe " ^ var.retries ^ "/" ^ global.mosTouchProbeNumProbes ^ ": X=" ^ var.curPos}

    ; Dwell so machine can settle
    G4 P{global.mosTouchProbeDwellTime}

    ; Drop speed in probe direction for next probe attempt
    M203 X{global.mosProbeSpeed}

    ; Iterate retry counter
    set var.retries = var.retries + 1

; Make sure to reset all speed limits after probing complete
M98 P"speed.g"

var probePosAveraged = var.probePos / global.mosTouchProbeNumProbes

M118 P0 L2 S{"X=" ^ var.probePosAveraged}

; Absolute moves to find ending position
G90

; Move to safe height
G53 G0 Z{param.S}

set global.mosProbeCoordinateX=var.probePosAveraged + var.probeCompensation