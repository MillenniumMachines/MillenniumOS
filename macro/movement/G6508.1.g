; G6508.1.g: OUTSIDE CORNER PROBE - EXECUTE
;
; Probe an outside corner of a workpiece, set target WCS X and Y
; co-ordinates to the probed corner, if requested.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { (!exists(param.Q) || param.Q == 0) && !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate X length and Y length using H and I parameters when using full probe, Q0!" }

; Maximum of 4 corners (0..3)
if { !exists(param.N) || param.N < 0 || param.N > 3 }
    abort { "Must provide a valid corner index (N..)!" }

if { exists(param.T) && param.T != null && param.T <= 0 }
    abort { "Surface clearance distance must be greater than 0!" }

if { exists(param.C) && param.C != null && param.C <= 0 }
    abort { "Corner clearance distance must be greater than 0!" }

if { exists(param.O) && param.O != null && param.O <= 0 }
    abort { "Overtravel distance must be greater than 0!" }

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Probe ID
var pID = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Probe mode defaults to (0=Full)
var pMO = { exists(param.Q)? param.Q : 0 }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Reset stored values that we're going to overwrite
; Reset corner, dimensions and rotation
M5010 W{var.workOffset} R50

; Get current machine position on Z
M5000 P1 I2

; Store our own safe Z position as the current position. We return to
; this position where necessary to make moves across the workpiece to
; the next probe point.
; We do this _after_ any switch to the touch probe, because while the
; original position may have been safe with a different tool installed,
; the touch probe may be longer. After a tool change the spindle
; will be parked, so essentially our safeZ is at the parking location.
var safeZ = { global.mosMI }

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

; Half of length of surfaces forming the corner
var hX   = { var.fX/2 }
var hY   = { var.fY/2 }

; Tool Radius is the first entry for each value in
; our extended tool table.

; Apply tool radius to surface clearance. We want to
; make sure the surface of the tool and the workpiece
; are the clearance distance apart, rather than less
; than that.
var surfaceClearance = { ((!exists(param.T) || param.T == null) ? global.mosCL : param.T) + ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Default corner clearance to the normal clearance
; distance, but allow it to be overridden if necessary.
var cornerClearance = { (!exists(param.C) || param.C == null) ? ((!exists(param.T) || param.T == null) ? global.mosCL : param.T) : param.C }

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Check that the clearance distance isn't
; higher than the width or height of the block if
; in full mode.
; Since we use the clearance distance to choose
; how far along each surface we should probe from
; the expected corners, a clearance higher than
; the width or height would mean we would try to
; probe off the edge of the block.
if { var.pMO == 0 && (var.cornerClearance >= var.hX || var.cornerClearance >= var.hY) }
    abort { "Corner clearance distance is more than half of the length of one or more surfaces forming the corner! Cannot probe." }

; The overtravel distance does not have the same
; requirement, as it is only used to adjust the
; probe target towards or away from the target
; surface rather.

; Y start location (K) direction is dependent on the chosen corner.
; If this is the front left corner, then our first probe is at
; var.sY + var.cornerClearance. If it is the back left corner, then our
; first probe is at var.sY - var.cornerClearance.

; Our second probe is always at the other end of the surface (away
; from the chosen corner), so we either add or subtract var.fY from
; the Y start location to get the second probe location.
; For each probe point: {start x, start y}, {target x, target y}
var dirXY = { vector(4 - var.pMO * 2, {{null, null}, {null, null}}) }

; Assign start and target positions based on direction
var dirX = { (param.N == 0 || param.N == 3) ? -1 : 1 }
var dirY = { (param.N == 0 || param.N == 1) ? 1 : -1 }

var startX = { var.sX + var.dirX * var.surfaceClearance }
var targetX = { var.sX - var.dirX * var.overtravel }

var startY = { var.sY + var.dirY * var.cornerClearance }
var targetY = { var.sY - var.dirY * var.overtravel }

; Set dirXY for X probes
set var.dirXY[0][0] = { var.startX, var.startY }
set var.dirXY[0][1] = { var.targetX, var.startY }

; Only probe the second X point if we're in full mode
if { var.pMO == 0 }
    set var.dirXY[2][0] = { var.startX, var.sY + var.dirY * (var.fY - var.cornerClearance) }
    set var.dirXY[2][1] = { var.targetX, var.sY + var.dirY * (var.fY - var.cornerClearance) }

; Set dirXY for Y probes
set var.dirX = { -var.dirX }
set var.dirY = { -var.dirY }

set var.startX = { var.sX + var.dirX * var.cornerClearance }
set var.targetX = { var.sX - var.dirX * var.overtravel }

set var.startY = { var.sY + var.dirY * var.surfaceClearance }
set var.targetY = { var.sY - var.dirY * var.overtravel }

set var.dirXY[1][0] = { var.startX, var.startY }
set var.dirXY[1][1] = { var.startX, var.targetY }

; Only probe the second Y point if we're in full mode
if { var.pMO == 0 }
    set var.dirXY[3][0] = { var.sX + var.dirX * (var.fX - var.cornerClearance), var.startY }
    set var.dirXY[3][1] = { var.sX + var.dirX * (var.fX - var.cornerClearance), var.targetY }

; Assign result variables
var pX = { vector(4 - var.pMO * 2, null) }
var pY = { vector(4 - var.pMO * 2, null) }

; Move outside X surface
G6550 I{var.pID} X{var.dirXY[0][0][0]}

; Move down to probe position
G6550 I{var.pID} Z{var.sZ}

; Move to start Y position
G6550 I{var.pID} Y{var.dirXY[0][0][1]}

; Run X probe 1
G6512 D1 I{var.pID} J{var.dirXY[0][0][0]} L{var.sZ} X{var.dirXY[0][1][0]}
set var.pX[0] = { global.mosMI[0] }
set var.pY[0] = { var.dirXY[0][0][1] }

; Return to our starting position
G6550 I{var.pID} X{var.dirXY[0][0][0]}

if { var.pMO == 0 }
    G6512 D1 I{var.pID} J{var.dirXY[2][0][0]} K{var.dirXY[2][0][1]} L{var.sZ} X{var.dirXY[2][1][0]}
    set var.pX[2] = { global.mosMI[0] }
    set var.pY[2] = { var.dirXY[2][0][1] }

    ; Return to our starting position.
    G6550 I{var.pID} X{var.dirXY[2][0][0]}

; Move to new start position in Y first
; NOTE: Always move in Y first. We probe
; X and then Y, if we move in X first then
; we will collide with the workpiece when
; we switch 'sides'.
G6550 I{var.pID} Y{var.dirXY[1][0][1]}

; And then X
G6550 I{var.pID} X{var.dirXY[1][0][0]}

; Run Y probes
G6512 D1 I{var.pID} K{var.dirXY[1][0][1]} L{var.sZ} Y{var.dirXY[1][1][1]}
set var.pX[1] = { var.dirXY[1][0][0] }
set var.pY[1] = { global.mosMI[1] }

; Return to our starting position
G6550 I{var.pID} Y{var.dirXY[1][0][1]}

if { var.pMO == 0 }
    G6512 D1 I{var.pID} J{var.dirXY[3][0][0]} K{var.dirXY[3][0][1]} L{var.sZ} Y{var.dirXY[3][1][1]}
    set var.pX[3] = { var.dirXY[3][0][0] }
    set var.pY[3] = { global.mosMI[1] }

    ; Return to our starting position
    G6550 I{var.pID} Y{var.dirXY[3][0][1]}

; Raise the probe
G6550 I{var.pID} Z{var.safeZ}

; Calculate corner position
var cX = null
var cY = null

; Full mode (P=0) or unset
if { var.pMO == 0 }
    ; Calculate corner position in full mode.

    ; We need to calculate the lines through the probed points
    ; on each axis.
    ; The lines do not currently cross because we probed inwards
    ; from the corner. We need to extend the lines to the edge
    ; of the work area, and then identify where they cross.
    ; This is the corner position.
    ; The X surface is defined by the line var.pX[0] -> var.pX[1]
    ; and var.pY[0] -> var.pY[1], and the Y surface is defined
    ; by the line var.pX[2] -> var.pX[3] and var.pY[2] -> var.pY[3].

    ; Calculate normals for both lines
    var mX = { (var.pY[1] - var.pY[0]) / (var.pX[1] - var.pX[0]) }
    var mY = { (var.pY[3] - var.pY[2]) / (var.pX[3] - var.pX[2]) }

    ; Extend both lines by the 2*clearance distance
    var eX = { var.pX[0] - (2*var.cornerClearance * cos(atan2(var.pY[2] - var.pY[0], var.pX[2] - var.pX[0]))) }
    var eY = { var.pY[1] - (2*var.cornerClearance * sin(atan2(var.pY[3] - var.pY[1], var.pX[3] - var.pX[1]))) }

    ; Calculate the intersection of the extended lines
    ; If the gradient of either line is 0, then the
    ; intersection on that axis is the first probed point.
    set var.cX = { (isnan(var.mX)) ? ((var.eY - var.pY[0] + (var.mX * var.pX[0]) - (var.mY * var.eX)) / (var.mX - var.mY)) : var.pX[0] }
    set var.cY = { (isnan(var.mY)) ? ((var.mX * (var.cX - var.pX[0])) + var.pY[0]) : var.pY[1] }

    ; We validate mX and mY above so these should never be NaN
    ; but check anyway, because RRF does weird things when given
    ; NaN values.
    if { isnan(var.cX) || isnan(var.cY) }
        abort { "Could not calculate corner position!" }

    ; Calculate the angle of the surfaces in relation to the X
    ; axis. A square workpiece squared to the table should have
    ; an angle of 90 degrees for aX (the X surface is perpendicular
    ; to the X axis) and 0 degrees for aY (the Y surface is parallel
    ; to the X axis).
    var aX = { atan2(var.pY[2] - var.pY[0], var.pX[2] - var.pX[0]) }
    var aY = { atan2(var.pY[3] - var.pY[1], var.pX[3] - var.pX[1]) }

    ; Angle difference. This will be different depending on which corner
    ; is being probed. We add 360 and take the modulo of 180 to make sure
    ; this stays a positive value less than 180 (ideally around 90).
    var diff = { abs(degrees(var.aX - var.aY)) }
    set global.mosWPCnrDeg[var.workOffset] = { mod(var.diff + 360, 180) }

    ; Calculate the rotation based on the length of the surface.
    ; Longer surfaces are more likely to be accurate due to the
    ; distance between the probe points.
    ; If the Y surface is longer, no adjustment is necessary.
    ; If the X surface is longer, we need to subtract 90 degrees
    ; from the angle.

    ; Example values:
    ;  Back Left: var.aX: -89.9213333 var.aY: 0.0450074
    ;  Front Left: var.aX: 90.08427 var.aY: 0.0553877
    ;  Front Right: var.aX: 90.08710 var.aY: -179.9480591
    ;  Back Right: var.aX: -89.9101028 var.aY: -179.9532471

    var aR = { degrees((var.fX > var.fY) ? var.aX - radians(90) : var.aY) }

    if { var.aR > 90 }
        set var.aR = { var.aR - 180 }
    elif { var.aR < -90 }
        set var.aR = { var.aR + 180 }

    if { var.aR > 45 }
        set var.aR = { var.aR - 90 }
    elif { var.aR < -45 }
        set var.aR = { var.aR + 90 }

    set global.mosWPDeg[var.workOffset] = { var.aR }

    ; Calculate the center of the workpiece based on the corner position,
    ; the width and height of the workpiece and the rotation.
    set global.mosWPCtrPos[var.workOffset] = { var.cX + ((var.fX/2) * cos(radians(var.aR)) - (var.fY/2) * sin(radians(var.aR))), var.cY + ((var.fX/2) * sin(radians(var.aR)) + (var.fY/2) * cos(radians(var.aR))) }

    ; If running in full mode, operator provided approximate width and
    ; height values of the workpiece. Assign these to the global
    ; variables for the workpiece width and height.
    ; This assumes that the workpiece is rectangular.
    set global.mosWPDims[var.workOffset] = { var.fX, var.fY }

else
    ; Calculate corner position in quick mode.
    set var.cX = { var.pX[0] }
    set var.cY = { var.pY[1] }

    set global.mosWPCnrDeg[var.workOffset] = { 90 }

; Move above the corner position
G6550 I{var.pID} X{var.cX} Y{var.cY}

; Set corner position
set global.mosWPCnrPos[var.workOffset] = { var.cX, var.cY }

; Set corner number
set global.mosWPCnrNum[var.workOffset] = { param.N }

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}

; Set WCS origin to the probed corner
echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " X,Y origin to " ^ global.mosCornerNames[param.N] ^ " corner." }
G10 L2 P{var.wcsNumber} X{var.cX} Y{var.cY}