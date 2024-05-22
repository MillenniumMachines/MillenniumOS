; G6520.1.g: VISE CORNER - EXECUTE
;
; Probe the top surface of a workpiece
; and then probe the corner surfaces to
; set X, Y and Z positions in the work offset
; in one go.
;
;
; J, K and L indicate the start X, Y and Z
; positions of the probe, which should be
; over the corner in question.
; If W is specified, the WCS origin will be set
; to the top surface at the probed corner.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 1 || param.W > limits.workplaces) }
    abort { "WCS number (W..) must be between 1 and " ^ limits.workplaces ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate X length and Y length using H and I parameters!" }

if { !exists(param.P) }
    abort { "Must provide a probe depth below the top surface using the P parameter!" }

if { (!exists(param.Q) || param.Q == 0) && !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate X length and Y length using H and I parameters when using full probe, Q0!" }

if { !exists(param.N) || param.N < 0 || param.N >= (#global.mosCnr) }
    abort { "Must provide a valid corner index using the N parameter!" }

var wpNum = { exists(param.W) && param.W != null ? param.W : limits.workplaces }

var probeId = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Store our own safe Z position as the current position. We return to
; this position where necessary to make moves across the workpiece to
; the next probe point.
; We do this _after_ any switch to the touch probe, because while the
; original position may have been safe with a different tool installed,
; the touch probe may be longer. After a tool change the spindle
; will be parked, so essentially our safeZ is at the parking location.
var safeZ = { move.axes[2].machinePosition }

; Above the corner to be probed
; J = start position X
; K = start position Y
; L = start position Z - our probe height
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; Specify R0 so that the underlying macros dont report their own
; debug info.

; Probe the top surface of the workpiece from the current Z position
G6510.1 R0 W{exists(param.W)? param.W : null} H4 I{param.T} O{param.O} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{var.safeZ}
if { global.mosWPSfcPos[var.wpNum] == global.mosDfltWPSfcPos || global.mosWPSfcAxis[var.wpNum] != "Z" }
    abort { "G6520: Failed to probe the top surface of the workpiece!" }

; Probe the corner surface
G6508.1 R0 W{exists(param.W)? param.W : null} Q{param.Q} H{param.H} I{param.I} N{param.N} T{param.T} O{param.O} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{ global.mosWPSfcPos - param.P}
if { global.mosWPCnrNum[var.wpNum] == null }
    abort { "G6520: Failed to probe the corner surface of the workpiece!" }

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.wpNum}