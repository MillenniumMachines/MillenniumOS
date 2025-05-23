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

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.P) }
    abort { "Must provide a probe depth below the top surface using the P parameter!" }

if { (!exists(param.Q) || param.Q == 0) && (!exists(param.H) || !exists(param.I)) }
    abort { "Must provide an approximate X length and Y length using H and I parameters when using full probe, Q0!" }

if { !exists(param.N) || param.N < 0 || param.N >= (#global.mosCornerNames) }
    abort { "Must provide a valid corner index using the N parameter!" }

if { exists(param.T) && param.T != null && param.T <= 0 }
    abort { "Surface clearance distance must be greater than 0!" }

if { exists(param.C) && param.C != null && param.C <= 0 }
    abort { "Corner clearance distance must be greater than 0!" }

if { exists(param.O) && param.O != null && param.O <= 0 }
    abort { "Overtravel distance must be greater than 0!" }

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

var probeId = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    abort { "Must run T" ^ global.mosPTID ^ " to select the probe tool before probing!" }

; Specify R0 so that the underlying macros dont report their own
; debug info.

; Probe the top surface of the workpiece from the current Z position
G6510.1 R0 W{var.workOffset} H4 I{param.T} O{param.O} J{param.J} K{param.K} L{param.L}
if { global.mosWPSfcPos[var.workOffset] == global.mosDfltWPSfcPos || global.mosWPSfcAxis[var.workOffset] != "Z" }
    abort { "G6520: Failed to probe the top surface of the workpiece!" }

; Get current machine position on Z
M5000 P1 I2

; Probe the corner surface
G6508.1 R0 W{var.workOffset} Q{param.Q} H{exists(param.H) ? param.H : null} I{exists(param.I) ? param.I : null} N{param.N} T{param.T} C{param.C} O{param.O} J{param.J} K{param.K} L{ global.mosMI } Z{global.mosWPSfcPos[var.workOffset] - param.P }
if { global.mosWPCnrNum[var.workOffset] == null }
    abort { "G6520: Failed to probe the corner surface of the workpiece!" }

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}