; G6502.1.g: RECTANGLE BLOCK - EXECUTE
;
; Probe the X and Y edges of a rectangular block.
; Calculate the dimensions of the block and set the
; WCS origin to the probed center of the block, if requested.

var maxWCS = #global.mosWorkOffsetCodes
if { exists(param.W) && (param.W < 1 || param.W > var.maxWCS) }
    abort { "WCS number (W..) must be between 1 and " ^ var.maxWCS ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate width and height using H and I parameters!" }

; J = start position X
; K = start position Y
; L = start position Z - our probe height
; H = approximate width of block in X
; I = approximate width of block in Y

; Start position calculated from operator chosen center of block.
; We only have to calculate 2 base starting positions, as the other
; 2 are calculated.
;            LEFT EDGE              RIGHT EDGE
var sX   = { param.J - (param.H/2), param.J + (param.H/2) }
;            FRONT EDGE             REAR EDGE
var sY   = { param.K - (param.I/2), param.K + (param.I/2) }

var sZ   = { param.L }

; Calculate probing directions, 4 probes total
; Probe back towards the center of the block
;             LEFT EDGE                    RIGHT EDGE
var dirX  = { var.sX + (param.H/2), var.sX - (param.H/2) }
;             FRONT EDGE                   REAR EDGE
var dirY  = { var.sY + (param.I/2), var.sY - (param.I/2) }

; Rectangular block edge co-ordinates in X
var pX   = { null, null }
; Rectangular block edge co-ordinates in Y
var pY   = { null, null }

; Probe edge min on X axis
G6510.1 K{global.mosTouchProbeID} J{var.sX[0]} K{param.K} L{param.L} X{dirX[0]}
set var.pX[0] = { global.mosProbeCoordinate[global.mosIX] }

; Probe edge max on X axis
G6510.1 K{global.mosTouchProbeID} J{var.sX[1]} K{param.K} L{param.L} X{dirX[1]}
set var.pX[1] = { global.mosProbeCoordinate[global.mosIX] }

set global.mosRectangleBlockDimensions[0] = { var.pX[1] - var.pX[0] }
set global.mosRectangleBlockCenterPos[0] = { (var.pX[0] + var.pX[1]) / 2 }

; Probe edge min on Y axis, using the X center of the pocket
G6510.1 K{global.mosTouchProbeID} J{global.mosRectangleBlockCenterPos[0]} K{var.sY[0]} L{param.L} Y{dirY[0]}
set var.pY[0] = { global.mosProbeCoordinate[global.mosIY] }

; Probe edge max on Y axis, using the X center of the pocket
G6510.1 K{global.mosTouchProbeID} J{global.mosRectangleBlockCenterPos[0]} K{var.sY[1]} L{param.L} Y{dirY[1]}
set var.pY[1] = { global.mosProbeCoordinate[global.mosIY] }

set global.mosRectangleBlockDimensions[1] = { var.pY[1] - var.pY[0] }
set global.mosRectangleBlockCenterPos[1] = { (var.pY[0] + var.pY[1]) / 2 }

if { !global.mosExpertMode }
    echo { "Rectangle block - Center X,Y:" ^ global.mosRectangleBlockCenterPos ^ " Dimensions X,Y:" ^ global.mosRectangleBlockDimensions }
else
    echo { "global.mosRectangleBlockCenterPos=" ^ global.mosRectangleBlockCenterPos }
    echo { "global.mosRectangleBlockDimensions=" ^ global.mosRectangleBlockDimensions }

; Set WCS origin to the probed corner, if requested
if { exists(param.W) }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin to center of rectangle block" }
    G10 L2 P{param.W} X{global.mosRectangleBlockCenterPos[0]} Y{global.mosRectangleBlockCenterPos[1]}