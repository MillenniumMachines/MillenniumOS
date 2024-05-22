; G6501.1.g: BOSS - EXECUTE
;
; Probe the outside surface of a boss.
;
; J, K and L indicate the start X, Y and Z
; positions of the probe, which should be an
; approximate center of the boss, below the
; top surface.
; H indicates the approximate boss diameter,
; and is used to calculate a probing radius along
; with T, the clearance distance.
; If W is specified, the WCS origin will be set
; to the center of the boss.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 1 || param.W > limits.workplaces) }
    abort { "WCS number (W..) must be between 1 and " ^ limits.workplaces ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) }
    abort { "Must provide an approximate boss diameter using the H parameter!" }

var wpNum = { exists(param.W) && param.W != null ? param.W : limits.workplaces }

var probeId = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Reset stored values that we're going to overwrite -
; center and radius
M4010 W{var.wpNum} R3

; Tool Radius is the first entry for each value in
; our extended tool table.

; Apply tool radius to clearance. We want to make sure
; the surface of the tool and the workpiece are the
; clearance distance apart, rather than less than that.
var clearance = { (exists(param.T) ? param.T : global.mosCL) + ((state.currentTool <= limits.tools-1 && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool <= limits.tools-1 && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Commented due to memory limitations
; M7500 S{"Distance Modifiers adjusted for Tool Radius - Clearance=" ^ var.clearance ^ " Overtravel=" ^ var.overtravel }

; We add the clearance distance to the boss
; radius to ensure we move clear of the boss
; before dropping to probe height.
var cR = { (param.H / 2) }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

; Start position is operator chosen center of the boss
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; Calculate probing directions using approximate boss radius
; Angle is in degrees
var angle = { radians(120) }

; For each probe point: {start x, start y}, {target x, target y}
var dirXY = { vector(3, {{null, null}, {null, null}}) }

; The start position is the approximate radius of the boss plus
; the clearance at 3 points around the center of the boss, at
; 120 degree intervals.
; The target position is the approximate radius of the boss minus
; the overtravel distance, at the same 3 points around the center
; of the boss, at 120 degree intervals.

; Start position probe 1
set var.dirXY[0][0] = { var.sX + var.cR + var.clearance, var.sY }

; Target position probe 1
set var.dirXY[0][1] = { var.sX + var.cR - var.overtravel, var.sY }

; Start position probe 2 (120 degrees)
set var.dirXY[1][0] = { var.sX + (var.cR + var.clearance)*cos(var.angle), var.sY + (var.cR + var.clearance)*sin(var.angle) }

; Target position probe 2 (120 degrees)
set var.dirXY[1][1] = { var.sX + (var.cR - var.overtravel)*cos(var.angle), var.sY + (var.cR - var.overtravel)*sin(var.angle) }

; Start position probe 3 (240 degrees)
set var.dirXY[2][0] = { var.sX + (var.cR + var.clearance)*cos(var.angle*2), var.sY + (var.cR + var.clearance)*sin(var.angle*2) }

; Target position probe 3 (240 degrees)
set var.dirXY[2][1] = { var.sX + (var.cR - var.overtravel)*cos(var.angle*2), var.sY + (var.cR - var.overtravel)*sin(var.angle*2) }

; Boss edge co-ordinates for 3 probed points
var pXY  = { null, null, null }

var safeZ = { move.axes[2].machinePosition }

; Probe each of the 3 points
while { iterations < #var.dirXY }
    ; Perform a probe operation towards the center of the boss
    G6512 I{var.probeId} J{var.dirXY[iterations][0][0]} K{var.dirXY[iterations][0][1]} L{var.sZ} X{var.dirXY[iterations][1][0]} Y{var.dirXY[iterations][1][1]}

    ; Save the probed co-ordinates
    set var.pXY[iterations] = { global.mosPCX, global.mosPCY }

; Calculate the slopes, midpoints, and perpendicular bisectors
var sM1 = { (var.pXY[1][1] - var.pXY[0][1]) / (var.pXY[1][0] - var.pXY[0][0]) }
var sM2 = { (var.pXY[2][1] - var.pXY[1][1]) / (var.pXY[2][0] - var.pXY[1][0]) }

; Validate the slopes. These should never be NaN but if they are,
; we can't calculate the bore center position and we must abort.
if { isnan(var.sM1) || isnan(var.sM2) }
    abort { "Could not calculate boss center position!" }

var m1X = { (var.pXY[1][0] + var.pXY[0][0]) / 2 }
var m1Y = { (var.pXY[1][1] + var.pXY[0][1]) / 2 }
var m2X = { (var.pXY[2][0] + var.pXY[1][0]) / 2 }
var m2Y = { (var.pXY[2][1] + var.pXY[1][1]) / 2 }

var pM1 = { -1 / var.sM1 }
var pM2 = { -1 / var.sM2 }

if { var.pM1 == var.pM2 }
    abort { "Could not calculate boss center position!" }

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
set global.mosWPCtrPos[var.wpNum]   = { var.cX, var.cY }
set global.mosWPRad[var.wpNum]      = { var.avgR }

; Confirm we are at the safe Z height
G6550 I{var.probeId} Z{var.safeZ}

; Move to the calculated center of the boss
G6550 I{var.probeId} X{var.cX} Y{var.cY}

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.wpNum}

; Set WCS origin to the probed boss center, if requested
if { exists(param.W) && param.W != null }
    echo { "MillenniumOS: Setting WCS " ^ param.W ^ " X,Y origin to center of boss." }
    G10 L2 P{param.W} X{var.cX} Y{var.cY}