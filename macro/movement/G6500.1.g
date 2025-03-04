; G6500.1.g: BORE - EXECUTE
;
; Probe the inside surface of a bore.
;
; J, K and L indicate the start X, Y and Z
; positions of the probe, which should be an
; approximate center of the bore in X and Y, with
; the L value below the surface of the bore.

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


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Increment the probe surface and point totals for status reporting
set global.mosPRST = { global.mosPRST + 1 }
set global.mosPRPT = { global.mosPRPT + 3 }

var probeId = { global.mosFeatTouchProbe ? global.mosTPID : null }

; TODO: Validate minimum bore diameter we can probe based on
; dive height and back-off distance.

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    abort { "Must run T" ^ global.mosPTID ^ " to select the probe tool before probing!" }

; Reset stored values that we're going to overwrite
; Reset center position, rotation and radius
M5010 W{var.workOffset} R37

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool <= limits.tools-1 && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Commented due to memory limitations
; M7500 S{"Distance Modifiers adjusted for Tool Radius - Overtravel=" ^ var.overtravel }

; We add the overtravel to the bore radius to give the user
; some leeway. If their estimate of the bore diameter is too
; small, then the probe will not activate and the operation
; will fail.
var bR = { (param.H / 2) + var.overtravel }

; J = start position X
; K = start position Y
; L = start position Z
; Z = our probe height (absolute)

var safeZ = { param.L }

; Start position is operator chosen center of the bore
var sX   = { param.J }
var sY   = { param.K }

; Calculate probing directions using approximate bore radius
; Angle is in degrees
var angle = { radians(120) }

var dirXY = { { var.sX + var.bR, var.sY}, { var.sX + var.bR * cos(var.angle), var.sY + var.bR * sin(var.angle) }, { var.sX + var.bR * cos(2 * var.angle), var.sY + var.bR * sin(2 * var.angle) } }

; Bore edge co-ordinates for 3 probed points
var pXY  = { null, null, null }

; Probe each of the 3 points
while { iterations < #var.dirXY }
    ; Perform a probe operation
    ; D1 causes the probe macro to not return to the safe position after probing.
    ; Since we're probing multiple times from the same starting point, there's no
    ; need to raise and lower the probe between each probe point.
    G6512 D1 I{var.probeId} J{var.sX} K{var.sY} L{param.Z} X{var.dirXY[iterations][0]} Y{var.dirXY[iterations][1]}

    ; Save the probed co-ordinates
    set var.pXY[iterations] = { global.mosMI[0], global.mosMI[1] }

; Calculate the slopes, midpoints, and perpendicular bisectors
var sM1 = { (var.pXY[1][1] - var.pXY[0][1]) / (var.pXY[1][0] - var.pXY[0][0]) }
var sM2 = { (var.pXY[2][1] - var.pXY[1][1]) / (var.pXY[2][0] - var.pXY[1][0]) }

; Validate the slopes. These should never be NaN but if they are,
; we can't calculate the bore center position and we must abort.
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