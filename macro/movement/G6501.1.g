; G6500.2.g: BOSS - EXECUTE
;
; Probe the outside surface of a boss.
;
; J, K and L indicate the start X, Y and Z
; positions of the probe, which should be an
; approximate center of the boss, below the
; top surface.
; H indicates the approximate boss diameter,
; and is used to calculate a probing radius along
; with O, the overtravel distance.
; If W is specified, the WCS origin will be set
; to the center of the boss.

var maxWCS = #global.mosWorkOffsetCodes
if { exists(param.W) && param.W != null && (param.W < 1 || param.W > var.maxWCS) }
    abort { "WCS number (W..) must be between 1 and " ^ var.maxWCS ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) }
    abort { "Must provide an approximate boss diameter using the H parameter!" }

var overTravel = { (exists(param.O) ? param.O : global.mosProbeOvertravel) }

; We add the overtravel distance to the boss
; radius to ensure we start probing from outside
; the boss.
var bR = { (param.H / 2) + var.overTravel }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

; Start position is operator chosen center of the boss
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; Calculate probing directions using approximate boss radius
; Angle is in degrees
var angle = 120

var dirXY = { { var.sX + var.bR, var.sY}, { var.sX + var.bR * cos(radians(var.angle)), var.sY + var.bR * sin(radians(var.angle)) }, { var.sX + var.bR * cos(radians(2 * var.angle)), var.sY + var.bR * sin(radians(2 * var.angle)) } }

; Boss edge co-ordinates for 3 probed points
var pXY  = { null, null, null }

var safeZ = { move.axes[global.mosIZ].machinePosition }

; Probe each of the 3 points
while { iterations < #var.dirXY }
    ; Perform a probe operation towards the center of the boss
    G6510.1 I{global.mosTouchProbeID} J{var.dirXY[iterations][0]} K{var.dirXY[iterations][1]} L{var.sZ} X{var.sX} Y{var.sY}

    ; Save the probed co-ordinates
    set var.pXY[iterations] = { global.mosProbeCoordinate[global.mosIX], global.mosProbeCoordinate[global.mosIY] }

; Calculate the slopes, midpoints, and perpendicular bisectors
var sM1 = { (var.pXY[1][1] - var.pXY[0][1]) / (var.pXY[1][0] - var.pXY[0][0]) }
var sM2 = { (var.pXY[2][1] - var.pXY[1][1]) / (var.pXY[2][0] - var.pXY[1][0]) }

var m1X = { (var.pXY[1][0] + var.pXY[0][0]) / 2 }
var m1Y = { (var.pXY[1][1] + var.pXY[0][1]) / 2 }
var m2X = { (var.pXY[2][0] + var.pXY[1][0]) / 2 }
var m2Y = { (var.pXY[2][1] + var.pXY[1][1]) / 2 }

var pM1 = { -1 / var.sM1 }
var pM2 = { -1 / var.sM2 }

; Solve the equations of the lines formed by the perpendicular bisectors to find the circumcenter X,Y
var cX = { (var.pM2 * var.m2X - var.pM1 * var.m1X + var.m1Y - var.m2Y) / (var.pM2 - var.pM1) }
var cY = { var.pM1 * (var.cX - var.m1X) + var.m1Y }

; Calculate the radii from the circumcenter to each of the probed points
var r1 = { sqrt(pow((var.pXY[0][0] - var.cX), 2) + pow((var.pXY[0][1] - var.cY), 2)) }
var r2 = { sqrt(pow((var.pXY[1][0] - var.cX), 2) + pow((var.pXY[1][1] - var.cY), 2)) }
var r3 = { sqrt(pow((var.pXY[2][0] - var.cX), 2) + pow((var.pXY[2][1] - var.cY), 2)) }

; Calculate the average radius
var avgR = { (var.r1 + var.r2 + var.r3) / 3 }

; Update global vars
set global.mosBossCenterPos = { var.cX, var.cY }
set global.mosBossRadius = { var.avgR }

; Move to the calculated center of the boss
G6550.1 I{global.mosTouchProbeID} X{var.cX} Y{var.cY}

if { !global.mosExpertMode }
    echo { "Boss - Center X,Y:" ^ global.mosBossCenterPos ^ " Radius :" ^ global.mosBossRadius }
else
    echo { "global.mosBossCenterPos=" ^ global.mosBossCenterPos }
    echo { "global.mosBossRadius=" ^ global.mosBossRadius }

; Set WCS origin to the probed boss center, if requested
if { exists(param.W) && param.W != null }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin to center of boss" }
    G10 L2 P{param.W} X{var.cX} Y{var.cY}