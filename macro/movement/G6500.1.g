; G6500.1.g: BORE - EXECUTE
;
; Probe the inside of a bore.
; First, we probe the X and Y radius of the bore to
; determine a good center point. Then we
; rotate the target co-ordinates by 45 degrees and probe
; in 4 directions again. This gives us a calculated
; center that uses 8 directions to determine the center
; and radius.

var maxWCS = #global.mosWorkOffsetCodes
if { exists(param.W) && (param.W < 1 || param.W > var.maxWCS) }
    abort { "WCS number (W..) must be between 1 and " ^ var.maxWCS ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) }
    abort { "Must provide an approximate bore diameter using the H parameter!" }

var bR = { param.H / 2 }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

; Start position is operator chosen center of the bore
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; Calculate probing directions using approximate bore radius
var angle = 120 ; Probe angle in degrees

var dirXY = {
    { var.sX + var.bR, var.sY},
    { var.sX + var.bR * cos(radians(angle)), var.sY + var.bR * sin(radians(angle)) },
    { var.sX + var.bR * cos(radians(2 * angle)), var.sY + var.bR * sin(radians(2 * angle)) },
}

; Bore edge co-ordinates in X
var pXY  = { null, null, null }

; Probe each of the 3 points
while iterations < #dirXY
    G6510.1 K{global.mosTouchProbeID} J{var.sX} K{var.sY} L{var.sZ} X{dirXY[iterations][0]} Y{dirXY[iterations][1]}
    ; Save the probed co-ordinates
    set var.pXY[iterations] = { global.mosProbeCoordinate[global.mosIX], global.mosProbeCoordinate[global.mosIY] }

if { !global.mosExpertMode }
    echo { "Rectangle pocket - Center X,Y:" ^ global.mosPocketCenterPos ^ " Dimensions X,Y:" ^ global.mosPocketDimensions }
else
    echo { "global.mosPocketCenterPos=" ^ global.mosPocketCenterPos }
    echo { "global.mosPocketDimensions=" ^ global.mosPocketDimensions }

; Set WCS origin to the probed corner, if requested
if { exists(param.W) }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin to center of pocket" }
    G10 L2 P{param.W} X{global.mosPocketCenterPos[0]} Y{global.mosPocketCenterPos[1]}