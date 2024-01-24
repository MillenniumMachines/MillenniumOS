; G6508.1.g: INSIDE CORNER PROBE - EXECUTE
;
; Probe an inside corner of a workpiece, set target WCS X and Y
; co-ordinates to the probed corner, if requested.

if { !exists(param.H) || param.H < 0 || param.H > (#global.mosOriginCorners-1) }
    abort { "Must provide a valid corner index (H..)!" }

if { !exists(param.I) }
    abort { "Must provide distance inwards from corner to probe surfaces, in mm (I..)!" }

var maxWCS = #global.mosWorkOffsetCodes
if { exists(param.W) && (param.W < 1 || param.W > var.maxWCS) }
    abort { "WCS number (W..) must be between 1 and " ^ var.maxWCS ^ "!" }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

; TODO: Don't use min and max machine positions here,
; only probe a limited distance from the start position.

; Calculate all possible movement directions
; We only pick one of these depending on the corner selected
;             FL                           FR                           RR                           RL
var dirX  = { move.axes[global.mosIX].max, move.axes[global.mosIX].min, move.axes[global.mosIX].min, move.axes[global.mosIX].max  }
var dirY  = { move.axes[global.mosIY].max, move.axes[global.mosIY].max, move.axes[global.mosIY].min, move.axes[global.mosIY].min  }

; Calculate all possible start positions
; Again, we only pick one of these depending on the corner selected
;            FL                 FR                 RR                 RL
var sX   = { param.J + param.I, param.J - param.I, param.J - param.I, param.J + param.I }
var sY   = { param.K + param.I, param.K + param.I, param.K - param.I, param.K - param.I }

; Probe edge on X axis
G6510.1 K{global.mosTouchProbeID} J{var.sX[param.H]} K{var.sY[param.H]} L{param.L} X{var.dirX[param.H]}

; Probe edge on Y axis
G6510.1 K{global.mosTouchProbeID} J{var.sX[param.H]} K{var.sY[param.H]} L{param.L} Y{var.dirY[param.H]}

; Set most recent corner position variables
set global.mosOutsideCornerNum = param.H
set global.mosOutsideCornerPos = { global.mosProbeCoordinate[0], global.mosProbeCoordinate[1] }

if { !global.mosExpertMode }
    echo { "Outside " ^ global.mosOriginCorners[param.H] ^ " corner is {" ^ global.mosOutsideCornerPos ^ "}" }
else
    echo { "global.mosOutsideCornerNum=" ^ global.mosOutsideCornerNum }
    echo { "global.mosOutsideCornerPos=" ^ global.mosOutsideCornerPos }

; Set WCS origin to the probed corner, if requested
if { exists(param.W) }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin." }
    G10 L2 P{param.W} X{global.mosProbeCoordinate[global.mosIX]} Y{global.mosProbeCoordinate[global.mosIY]}