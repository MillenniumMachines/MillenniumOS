; G6500.1.g: BORE - EXECUTE
;
; Probe the inside surface of a bore.
;
; J, K and L indicate the start X, Y and Z
; positions of the probe, which should be an
; approximate center of the bore in X and Y, with
; the L value below the surface of the bore.
;
; H indicates the approximate bore diameter,
; and is used to calculate a probing radius along
; with O, the overtravel distance.
; If W is specified, the WCS origin will be set
; to the center of the bore.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.Z) }
    abort { "Must provide a probe position using the Z parameter!" }

if { !exists(param.H) }
    abort { "Must provide an approximate bore diameter using the H parameter!" }

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }
var wcsNumber = { var.workOffset + 1 }

; Increment the probe surface and point totals for status reporting
set global.mosPRST = { global.mosPRST + 1 }
set global.mosPRPT = { global.mosPRPT + 3 }

var probeId = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    abort { "Must run T" ^ global.mosPTID ^ " to select the probe tool before probing!" }

; Reset stored values that we're going to overwrite
; Reset center position, rotation and radius
M5010 W{var.workOffset} R37

; Apply tool radius to overtravel. We want to allow less movement past the expected point of contact
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool <= limits.tools-1 && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; We add the overtravel to the bore radius
var bR = { (param.H / 2) + var.overtravel }

; Store our own safe Z position as the current position. We return to
; this position where necessary to make moves across the workpiece to
; the next probe point.
; We do this _after_ any switch to the touch probe, because while the
; original position may have been safe with a different tool installed,
; the touch probe may be longer. After a tool change the spindle
; will be parked, so essentially our safeZ is at the parking location.
var safeZ = { param.L }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

; Start position is operator chosen center of the bore
var sX = { param.J }
var sY = { param.K }

; Create an array of probe points for G6513
var numPoints = 3
var probePoints = { vector(var.numPoints, {{null, null, null}, {null, null, null}}) }

; Set first probe point directly (0 degrees) to avoid rounding errors
set var.probePoints[0][0][0] = {var.sX, var.sY, param.Z}
set var.probePoints[0][0][1] = {var.sX + var.bR + var.overtravel, var.sY, param.Z}

; Generate remaining probe points
while { iterations < var.numPoints - 1 }
    var pointNo = { iterations + 1 }
    var probeAngle = { radians(120 * var.pointNo) }

    ; Set probe point directly with calculated positions
    ; We have to keep the lines short to avoid going over the 255 character limit
    ; So we should set each index separately
    set var.probePoints[var.pointNo][0][0] = { var.sX, var.sY, param.Z }
    set var.probePoints[var.pointNo][0][1] = { var.sX + (var.bR + var.overtravel) * cos(var.probeAngle), var.sY + (var.bR + var.overtravel) * sin(var.probeAngle), param.Z }

; Call G6513 to probe the points
G6513 I{var.probeId} P{var.probePoints} S{var.safeZ} D1

; Extract the compensated probe points from G6513's output
var result = { global.mosMI }
var pXY = { vector(3, null) }

; Get the probed points from each surface
while { iterations < #var.result }
    set var.pXY[iterations] = { var.result[iterations][0][0][0], var.result[iterations][0][0][1] }

; Calculate the slopes, midpoints, and perpendicular bisectors
var sM1 = { (var.pXY[1][1] - var.pXY[0][1]) / (var.pXY[1][0] - var.pXY[0][0]) }
var sM2 = { (var.pXY[2][1] - var.pXY[1][1]) / (var.pXY[2][0] - var.pXY[1][0]) }

; Validate the slopes
if { isnan(var.sM1) || isnan(var.sM2) }
    abort { "Could not calculate bore center position!" }

var m1X = { (var.pXY[1][0] + var.pXY[0][0]) / 2 }
var m1Y = { (var.pXY[1][1] + var.pXY[0][1]) / 2 }
var m2X = { (var.pXY[2][0] + var.pXY[1][0]) / 2 }
var m2Y = { (var.pXY[2][1] + var.pXY[1][1]) / 2 }

var pM1 = { -1 / var.sM1 }
var pM2 = { -1 / var.sM2 }

if { var.pM1 == var.pM2 }
    abort { "Could not calculate bore center position!" }

; Solve the equations of the lines formed by the perpendicular bisectors to find the circumcenter X,Y
var cX = { (var.pM2 * var.m2X - var.pM1 * var.m1X + var.m1Y - var.m2Y) / (var.pM2 - var.pM1) }
var cY = { var.pM1 * (var.cX - var.m1X) + var.m1Y }

; Calculate the radii from the circumcenter to each of the probed points
var r1 = { sqrt(pow((var.pXY[0][0] - var.cX), 2) + pow((var.pXY[0][1] - var.cY), 2)) }
var r2 = { sqrt(pow((var.pXY[1][0] - var.cX), 2) + pow((var.pXY[1][1] - var.cY), 2)) }
var r3 = { sqrt(pow((var.pXY[2][0] - var.cX), 2) + pow((var.pXY[2][1] - var.cY), 2)) }

; Calculate the average radius
var avgR = { (var.r1 + var.r2 + var.r3) / 3 }

; Update global vars for correct workplace
set global.mosWPCtrPos[var.workOffset]   = { var.cX, var.cY }
set global.mosWPRad[var.workOffset]      = { var.avgR }

; Move to the calculated center of the bore
G6550 I{var.probeId} X{var.cX} Y{var.cY}

; Move back to safe Z height
G6550 I{var.probeId} Z{var.safeZ}

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}
echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " X,Y origin to center of bore." }

; Set WCS origin to the probed center
G10 L2 P{var.wcsNumber} X{var.cX} Y{var.cY}