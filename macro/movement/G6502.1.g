; G6502.1.g: RECTANGLE POCKET - EXECUTE
;
; Probe the X and Y edges of a rectangular pocket.
; Calculate the dimensions of the pocket and set the
; WCS origin to the probed center of the pocket, if requested.

var maxWCS = #global.mosWorkOffsetCodes
if { exists(param.W) && (param.W < 1 || param.W > var.maxWCS) }
    abort { "WCS number (W..) must be between 1 and " ^ var.maxWCS ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

; TODO: Do not probe to axis maxima / minima, take a user dimension
; instead.

; Calculate probing directions, 4 probes total
;             LEFT EDGE                    RIGHT EDGE
var dirX  = { move.axes[0].min, move.axes[0].max }
;             FRONT EDGE                   REAR EDGE
var dirY  = { move.axes[1].max, move.axes[1].min }


; Start position is provided by operator and should be the approximate
; center in X and Y of the pocket, and the Z depth to probe at.
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; Pocket edge co-ordinates in X
var pX   = { null, null }

; Pocket edge co-ordinates in Y
var pY   = { null, null }

; Probe edge min on X axis
G6512 K{global.mosTouchProbeID} J{param.J} K{param.K} L{param.L} X{dirX[0]}
set var.pX[0] = { global.mosProbeCoordinate[0] }

; Probe edge max on X axis
G6512 K{global.mosTouchProbeID} J{param.J} K{param.K} L{param.L} X{dirX[1]}
set var.pX[1] = { global.mosProbeCoordinate[0] }

set global.mosRectanglePocketDimensions[0] = { var.pX[1] - var.pX[0] }
set global.mosRectanglePocketCenterPos[0] = { (var.pX[0] + var.pX[1]) / 2 }

; Probe edge min on Y axis, using the X center of the pocket
G6512 K{global.mosTouchProbeID} J{global.mosRectanglePocketCenterPos[0]} K{param.K} L{param.L} Y{dirY[0]}
set var.pY[0] = { global.mosProbeCoordinate[1] }

; Probe edge max on Y axis, using the X center of the pocket
G6512 K{global.mosTouchProbeID} J{global.mosRectanglePocketCenterPos[0]} K{param.K} L{param.L} Y{dirY[1]}
set var.pY[1] = { global.mosProbeCoordinate[1] }

set global.mosRectanglePocketDimensions[1] = { var.pY[1] - var.pY[0] }
set global.mosRectanglePocketCenterPos[1] = { (var.pY[0] + var.pY[1]) / 2 }

if { !global.mosExpertMode }
    echo { "Rectangle pocket - Center X,Y:" ^ global.mosRectanglePocketCenterPos ^ " Dimensions X,Y:" ^ global.mosRectanglePocketDimensions }
else
    echo { "global.mosRectanglePocketCenterPos=" ^ global.mosRectanglePocketCenterPos }
    echo { "global.mosRectanglePocketDimensions=" ^ global.mosRectanglePocketDimensions }

; Set WCS origin to the probed corner, if requested
if { exists(param.W) }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin to center of pocket" }
    G10 L2 P{param.W} X{global.mosRectanglePocketCenterPos[0]} Y{global.mosRectanglePocketCenterPos[1]}