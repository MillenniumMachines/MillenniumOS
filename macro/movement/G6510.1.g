; G6510.1.g: SINGLE SURFACE PROBE - EXECUTE
;
; Execute the single surface probe given
; the axis to probe, distance to probe in and
; the depth to probe at or towards.

if { exists(param.W) && param.W != null && (param.W < 1 || param.W > #global.mosWorkOffsetCodes) }
    abort { "WCS number (W..) must be between 1 and " ^ #global.mosWorkOffsetCodes ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) }
    abort { "Must provide an axis to probe (H...)" }

if { !exists(param.I) }
    abort { "Must provide a distance to probe towards the target surface (I...)" }

var probeId = { global.mosFeatureTouchProbe ? global.mosTouchProbeID : null }

set global.mosWorkPieceSurfacePos = null
set global.mosWorkPieceSurfaceAxis = null

; Make sure probe tool is selected
if { global.mosProbeToolID != state.currentTool }
    T T{global.mosProbeToolID}

var safeZ = { move.axes[2].machinePosition }

; Above the corner to be probed
; J = start position X
; K = start position Y
; L = start position Z - our probe height
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; We do not apply tool radius to overtravel, because we need overtravel for
; Z probes as well as X/Y. Tool radius only applies for X/Y probes.
var overtravel = { exists(param.O) ? param.O : global.mosProbeOvertravel }

; Tool Radius if tool is selected
var tR = { ((state.currentTool <= limits.tools-1 && state.currentTool >= 0) ? global.mosToolTable[state.currentTool][0] : 0) }

; Set target positions
var tPX = { var.sX }
var tPY = { var.sY }
var tPZ = { var.sZ }

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

; Check if the positions are within machine limits
G6515 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }


; Run probing operation
G6512 I{var.probeId} J{var.sX} K{var.sY} L{var.sZ} X{var.tPX} Y{var.tPY} Z{var.tPZ}

var sAxis = { (var.probeAxis <= 1)? "X" : (var.probeAxis <= 3)? "Y" : "Z" }

; Set the axis that we probed on
set global.mosWorkPieceSurfaceAxis = { var.sAxis }

; Set surface position on relevant axis
set global.mosWorkPieceSurfacePos = { (var.probeAxis <= 1)? global.mosProbeCoordinate[0] : (var.probeAxis <= 3)? global.mosProbeCoordinate[1] : global.mosProbeCoordinate[2] }

if { !exists(param.R) || param.R != 0 }
    if { !global.mosExpertMode }
        echo { "MillenniumOS: Surface - " ^ var.sAxis ^ "=" ^ global.mosWorkPieceSurfacePos }
    else
        echo { "global.mosWorkPieceSurfaceAxis=" ^ global.mosWorkPieceSurfaceAxis }
        echo { "global.mosWorkPieceSurfacePos=" ^ global.mosWorkPieceSurfacePos }

; Set WCS if required
if { exists(param.W) && param.W != null }
    echo { "Setting WCS " ^ param.W ^ " " ^ var.sAxis ^ " origin to probed co-ordinate" }
    if { var.probeAxis <= 1 }
        G10 L2 P{param.W} X{global.mosWorkPieceSurfacePos}
    elif { var.probeAxis <= 3 }
        G10 L2 P{param.W} Y{global.mosWorkPieceSurfacePos}
    else
        G10 L2 P{param.W} Z{global.mosWorkPieceSurfacePos}


; Save code of last probe cycle
set global.mosLastProbeCycle = "G6510"
