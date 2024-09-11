; G6510.1.g: SINGLE SURFACE PROBE - EXECUTE
;
; Execute the single surface probe given
; the axis to probe, distance to probe in and
; the depth to probe at or towards.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) }
    abort { "Must provide an axis to probe (H...)" }

if { !exists(param.I) }
    abort { "Must provide a distance to probe towards the target surface (I...)" }

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
    T T{global.mosPTID}

; Reset stored values that we're going to overwrite -
; surface
M5010 W{var.workOffset} R8

; Get current machine position on Z
M5000 P1 I2

var safeZ = { global.mosMI }

; We do not apply tool radius to overtravel, because we need overtravel for
; Z probes as well as X/Y. Tool radius only applies for X/Y probes.
var overtravel = { exists(param.O) ? param.O : global.mosOT }

; Tool Radius if tool is selected
var tR = { ((state.currentTool <= limits.tools-1 && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Set target positions
var tPX = { param.J }
var tPY = { param.K }
var tPZ = { param.L }

var probeAxis = { param.H }
var probeDist = { param.I }

if { var.probeAxis == 0 }
    set var.tPX = { var.tPX + var.probeDist + var.overtravel - var.tR }
elif { var.probeAxis == 1 }
    set var.tPX = { var.tPX - var.probeDist - var.overtravel + var.tR }
elif { var.probeAxis == 2 }
    set var.tPY = { var.tPY + var.probeDist + var.overtravel - var.tR }
elif { var.probeAxis == 3 }
    set var.tPY = { var.tPY - var.probeDist - var.overtravel + var.tR }
elif { var.probeAxis == 4 }
    set var.tPZ = { var.tPZ - var.probeDist - var.overtravel }
else
    abort { "Invalid probe axis!" }

; Check if the positions are within machine limits
M6515 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

; Run probing operation
G6512 I{var.probeId} J{param.J} K{param.K} L{param.L} X{var.tPX} Y{var.tPY} Z{var.tPZ}

var sAxis = { (var.probeAxis <= 1)? "X" : (var.probeAxis <= 3)? "Y" : "Z" }

; Set the axis that we probed on
set global.mosWPSfcAxis[var.workOffset] = { var.sAxis }

; Set surface position on relevant axis
set global.mosWPSfcPos[var.workOffset] = { (var.probeAxis <= 1)? global.mosMI[0] : (var.probeAxis <= 3)? global.mosMI[1] : global.mosMI[2] }

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}

; Set WCS if required
echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " " ^ var.sAxis ^ " origin to probed co-ordinate." }
if { var.probeAxis <= 1 }
    G10 L2 P{var.wcsNumber} X{global.mosWPSfcPos[var.workOffset]}
elif { var.probeAxis <= 3 }
    G10 L2 P{var.wcsNumber} Y{global.mosWPSfcPos[var.workOffset]}
else
    G10 L2 P{var.wcsNumber} Z{global.mosWPSfcPos[var.workOffset]}