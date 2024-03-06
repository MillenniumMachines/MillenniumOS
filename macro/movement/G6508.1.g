; G6508.1.g: OUTSIDE CORNER PROBE - EXECUTE
;
; Probe an outside corner of a workpiece, set target WCS X and Y
; co-ordinates to the probed corner, if requested.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Make sure we're in the default motion system
M598

if { exists(param.W) && param.W != null && (param.W < 1 || param.W > limits.workplaces) }
    abort { "WCS number (W..) must be between 1 and " ^ limits.workplaces ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate X length and Y length using H and I parameters!" }

; Maximum of 4 corners (0..3)
if { !exists(param.N) || param.N < 0 || param.N >= 3 }
    abort { "Must provide a valid corner index (N..)!" }

var probeId = { global.mosFeatTouchProbe ? global.mosTPID : null }

set global.mosWPCnrNum =  null
set global.mosWPCnrDeg = null
set global.mosWPCnrPos = { null, null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Store our own safe Z position as the current position. We return to
; this position where necessary to make moves across the workpiece to
; the next probe point.
; We do this _after_ any switch to the touch probe, because while the
; original position may have been safe with a different tool installed,
; the touch probe may be longer. After a tool change the spindle
; will be parked, so essentially our safeZ is at the parking location.
var safeZ = { move.axes[2].machinePosition }

; Above the corner to be probed
; J = start position X
; K = start position Y
; L = start position Z - our probe height
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; Length of surfaces on X and Y forming the corner
var fX   = { param.H }
var fY   = { param.I }

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

; Check that the clearance distance isn't
; higher than the width or height of the block.
; Since we use the clearance distance to choose
; how far along each surface we should probe from
; the expected corners, a clearance higher than
; the width or height would mean we would try to
; probe off the edge of the block.
if { var.clearance >= var.fX || var.clearance >= var.fY }
    abort { "Clearance distance is higher than the length of the surfaces to be probed! Cannot probe." }

; The overtravel distance does not have the same
; requirement, as it is only used to adjust the
; probe target towards or away from the target
; surface rather.

; Commented due to memory limitations
; M7500 S{"Distance Modifiers adjusted for Tool Radius - Clearance=" ^ var.clearance ^ " Overtravel=" ^ var.overtravel }

; Y start location (K) direction is dependent on the chosen corner.
; If this is the front left corner, then our first probe is at
; var.sY + var.clearance. If it is the back left corner, then our
; first probe is at var.sY - var.clearance.

; Our second probe is always at the other end of the surface (away
; from the chosen corner), so we either add or subtract var.fY from
; the Y start location to get the second probe location.
; If we add var.fY, then we need to subtract var.clearance and vice
; versa.
; For each probe point: {start x, start y}, {target x, target y}
var dirXY = { vector(4, {{null, null}, {null, null}}) }

; Assign start and target positions based on direction
var dirX = { (param.N == 0 || param.N == 3) ? -1 : 1 }
var dirY = { (param.N == 0 || param.N == 1) ? 1 : -1 }

var startX = { var.sX + var.dirX * var.clearance }
var targetX = { var.sX + var.dirX * var.overtravel }

var startY = { var.sY + var.dirY * var.clearance }
var targetY = { var.sY + var.dirY * var.overtravel }

; Set dirXY for X probes
set var.dirXY[0][0] = { var.startX, var.sY + var.dirY * var.clearance }
set var.dirXY[0][1] = { var.targetX, var.sY + var.dirY * var.clearance }
set var.dirXY[1][0] = { var.startX, var.sY + var.dirY * (var.fY - var.clearance) }
set var.dirXY[1][1] = { var.targetX, var.sY + var.dirY * (var.fY - var.clearance) }

set var.dirX = { -var.dirX }
set var.dirY = { -var.dirY }

set var.startX = { var.sX + var.dirX * var.clearance }
set var.targetX = { var.sX + var.dirX * var.overtravel }
set var.startY = { var.sY + var.dirY * var.clearance }
set var.targetY = { var.sY + var.dirY * var.overtravel }

set var.dirXY[2][0] = { var.sX + var.dirX * var.clearance, var.startY }
set var.dirXY[2][1] = { var.sX + var.dirX * var.clearance, var.targetY }
set var.dirXY[3][0] = { var.sX + var.dirX * (var.fX - var.clearance), var.startY }
set var.dirXY[3][1] = { var.sX + var.dirX * (var.fX - var.clearance), var.targetY }

var pX = { null, null, null, null }
var pY = { null, null, null, null }

; Move outside X surface
G6550 I{var.probeId} X{var.dirXY[0][0][0]}

; Move down to probe position
G6550 I{var.probeId} Z{var.sZ}

; Move to start Y position
G6550 I{var.probeId} Y{var.dirXY[0][0][1]}

; Run X probe 1
G6512 D1 I{var.probeId} J{var.dirXY[0][0][0]} K{var.dirXY[0][0][1]} L{var.sZ} X{var.dirXY[0][1][0]}
set var.pX[0] = { global.mosPCX }
set var.pY[0] = { global.mosPCY }

; Return to our starting position
G6550 I{var.probeId} X{var.dirXY[0][0][0]}

G6512 D1 I{var.probeId} J{var.dirXY[1][0][0]} K{var.dirXY[1][0][1]} L{var.sZ} X{var.dirXY[1][1][0]}
set var.pX[1] = { global.mosPCX }
set var.pY[1] = { global.mosPCY }

; Return to our starting position.
G6550 I{var.probeId} X{var.dirXY[1][0][0]}

; Move to new start position in Y first
; NOTE: Always move in Y first. We probe
; X and then Y, if we move in X first then
; we will collide with the workpiece when
; we switch 'sides'.
G6550 I{var.probeId} Y{var.dirXY[2][0][1]}

; And then X
G6550 I{var.probeId} X{var.dirXY[2][0][0]}

; Run Y probes
G6512 D1 I{var.probeId} J{var.dirXY[2][0][0]} K{var.dirXY[2][0][1]} L{var.sZ} Y{var.dirXY[2][1][1]}
set var.pX[2] = { global.mosPCX }
set var.pY[2] = { global.mosPCY }

; Return to our starting position
G6550 I{var.probeId} Y{var.dirXY[2][0][1]}

G6512 D1 I{var.probeId} J{var.dirXY[3][0][0]} K{var.dirXY[3][0][1]} L{var.sZ} Y{var.dirXY[3][1][1]}
set var.pX[3] = { global.mosPCX }
set var.pY[3] = { global.mosPCY }

; Return to our starting position and then raise the probe
G6550 I{var.probeId} Y{var.dirXY[3][0][1]}

G6550 I{var.probeId} Z{var.safeZ}

; Calculate corner position
; We need to calculate the lines through the probed points
; on each axis.
; The lines do not currently cross because we probed inwards
; from the corner. We need to extend the lines to the edge
; of the work area, ""OK""and then identify where they cross.
; those lines cross. This is the corner position.
; The X surface is defined by the line var.pX[0] -> var.pX[1]
; and var.pY[0] -> var.pY[1], and the Y surface is defined
; by the line var.pX[2] to var.pY[3] and var.pY[2] to var.pY[3].

; Calculate normals for both lines
var mX = { (var.pY[1] - var.pY[0]) / (var.pX[1] - var.pX[0]) }
var mY = { (var.pY[3] - var.pY[2]) / (var.pX[3] - var.pX[2]) }

; Extend both lines by the clearance distance
var eX = { var.pX[0] - (var.clearance * cos(atan2(var.pY[1] - var.pY[0], var.pX[1] - var.pX[0]))) }
var eY = { var.pY[2] - (var.clearance * sin(atan2(var.pY[3] - var.pY[2], var.pX[3] - var.pX[2]))) }

; Calculate the intersection of the extended lines
var cX = { (var.eY - var.pY[0] + (var.mX * var.pX[0]) - (var.mY * var.eX)) / (var.mX - var.mY) }
var cY = { (var.mX * (var.cX - var.pX[0])) + var.pY[0] }

; Calculate the angle of the surfaces in relation to the X
; axis. A square workpiece squared to the table should have
; an angle of 90 degrees for aX (the X surface is perpendicular
; to the X axis) and 0 degrees for aY (the Y surface is parallel
; to the X axis).
var aX = { atan2(var.pY[1] - var.pY[0], var.pX[1] - var.pX[0]) }
var aY = { atan2(var.pY[3] - var.pY[2], var.pX[3] - var.pX[2]) }

; This is the corner angle
set global.mosWPCnrDeg = { abs(degrees(var.aX - var.aY)) }

; Move above the corner position
G6550 I{var.probeId} X{var.cX} Y{var.cY}

; Set corner position
set global.mosWPCnrPos = { var.cX, var.cY }

; Set corner number
set global.mosWPCnrNum = { param.N }

if { !exists(param.R) || param.R != 0 }
    if { !global.mosEM }
        echo { "Outside " ^ global.mosCnr[param.N] ^ " corner is X=" ^ global.mosWPCnrPos[0] ^ " Y=" ^ global.mosWPCnrPos[1] ^ ", angle is " ^ global.mosWPCnrDeg ^ " degrees" }
    else
        echo { "global.mosWPCnrNum=" ^ global.mosWPCnrNum }
        echo { "global.mosWPCnrPos=" ^ global.mosWPCnrPos }
        echo { "global.mosWPCnrDeg=" ^ global.mosWPCnrDeg }

; Set WCS origin to the probed center, if requested
if { exists(param.W) && param.W != null }
    echo { "MillenniumOS: Setting WCS " ^ param.W ^ " X,Y origin to corner " ^ global.mosCnr[param.N] }
    G10 L2 P{param.W} X{global.mosWPCnrPos[0]} Y{global.mosWPCnrPos[1]}