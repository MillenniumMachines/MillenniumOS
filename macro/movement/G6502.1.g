; G6502.1.g: RECTANGLE POCKET - EXECUTE
;
; Probe the X and Y edges of a rectangular pocket.
; Calculate the dimensions of the pocket and set the
; WCS origin to the probed center of the pocket, if requested.

if { exists(param.W) && param.W != null && (param.W < 1 || param.W > #global.mosWorkOffsetCodes) }
    abort { "WCS number (W..) must be between 1 and " ^ #global.mosWorkOffsetCodes ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate width and height using H and I parameters!" }

var probeId = { global.mosFeatureTouchProbe ? global.mosTouchProbeID : null }

; Make sure probe tool is selected
if { global.mosProbeToolID != state.currentTool }
    T T{global.mosProbeToolID}

; Tool Radius is the first entry for each value in
; our extended tool table.

; Apply tool radius to clearance. We want to make sure
; the surface of the tool and the workpiece are the
; clearance distance apart, rather than less than that.
var clearance = { (exists(param.T) ? param.T : global.mosProbeClearance) + global.mosToolTable[state.currentTool][0] }

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosProbeOvertravel) - global.mosToolTable[state.currentTool][0] }

M7500 S{"Distance Modifiers adjusted for Tool Radius - Clearance=" ^ var.clearance ^ " Overtravel=" ^ var.overtravel }


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
G6512 I{var.probeId} J{param.J} K{param.K} L{param.L} X{dirX[0]}
set var.pX[0] = { global.mosProbeCoordinate[0] }

; Probe edge max on X axis
G6512 I{var.probeId} J{param.J} K{param.K} L{param.L} X{dirX[1]}
set var.pX[1] = { global.mosProbeCoordinate[0] }

set global.mosWorkPieceDimensions[0] = { var.pX[1] - var.pX[0] }
set global.mosWorkPieceCenterPos[0] = { (var.pX[0] + var.pX[1]) / 2 }

; Probe edge min on Y axis, using the X center of the pocket
G6512 I{var.probeId} J{global.mosWorkPieceCenterPos[0]} K{param.K} L{param.L} Y{dirY[0]}
set var.pY[0] = { global.mosProbeCoordinate[1] }

; Probe edge max on Y axis, using the X center of the pocket
G6512 I{var.probeId} J{global.mosWorkPieceCenterPos[0]} K{param.K} L{param.L} Y{dirY[1]}
set var.pY[1] = { global.mosProbeCoordinate[1] }

set global.mosWorkPieceDimensions[1] = { var.pY[1] - var.pY[0] }
set global.mosWorkPieceCenterPos[1] = { (var.pY[0] + var.pY[1]) / 2 }

if { !global.mosExpertMode }
    echo { "Rectangle Pocket - Center X=" ^ global.mosWorkPieceCenterPos[0] ^ " Y=" ^ global.mosWorkPieceCenterPos[1] ^ " Dimensions X=" ^ global.mosWorkPieceDimensions[0] ^ " Y=" ^ global.mosWorkPieceDimensions[1] }
else
    echo { "global.mosWorkPieceCenterPos=" ^ global.mosWorkPieceCenterPos }
    echo { "global.mosWorkPieceDimensions=" ^ global.mosWorkPieceDimensions }

; Set WCS origin to the probed center, if requested
if { exists(param.W) && param.W != null }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin to center of pocket" }
    G10 L2 P{param.W} X{global.mosWorkPieceCenterPos[0]} Y{global.mosWorkPieceCenterPos[1]}