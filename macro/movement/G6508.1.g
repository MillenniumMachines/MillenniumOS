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

if { !exists(param.Z) }
    abort { "Must provide a probe position using the Z parameter!" }

if { (!exists(param.Q) || param.Q == 0) && (!exists(param.H) || !exists(param.I) || param.H == null || param.I == null) }
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
var pFull = { exists(param.Q) ? param.Q == 0: false }

; Increment the probe surface and point totals for status reporting
set global.mosPRST = { global.mosPRST + (var.pFull ? 2 : 1) }
set global.mosPRPT = { global.mosPRPT + (var.pFull ? 4 : 2) }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    abort { "Must run T" ^ global.mosPTID ^ " to select the probe tool before probing!" }

; Reset stored values that we're going to overwrite
; Reset corner, dimensions and rotation
M5010 W{var.workOffset} R50

; Store our own safe Z position as the current position. We return to
; this position where necessary to make moves across the workpiece to
; the next probe point.
; We do this _after_ any switch to the touch probe, because while the
; original position may have been safe with a different tool installed,
; the touch probe may be longer. After a tool change the spindle
; will be parked, so essentially our safeZ is at the parking location.
var safeZ = { param.L }

; Above the corner to be probed
; J = start position X
; K = start position Y
; L = start position Z
; Z = our probe height (absolute)

var sX   = { param.J }
var sY   = { param.K }


; Length of surfaces on X and Y forming the corner
; These are null when in quick mode, as using 0 could
; lead to unintended maths consequences. It is invalid
; to use these values in quick mode so we should always
; error out if they are used.
var fX   = { (var.pFull) ? param.H : null }
var fY   = { (var.pFull) ? param.I : null }

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
if { var.pFull }
    if { (var.cornerClearance >= (var.fX/2) || var.cornerClearance >= (var.fY/2)) }
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
; For each probe point: {start x, start y, start z}, {target x, target y, target z}
; In full mode we have 2 points per surface, otherwise 1.
var points = { vector(2 - (var.pFull ? 0 : 1), {{null, null, param.Z}, {null, null, param.Z}}) }

var surface1 = { var.points }
var surface2 = { var.points }

; Assign start and target positions based on direction
var dirX = { (param.N == 0 || param.N == 3) ? -1 : 1 }
var dirY = { (param.N == 0 || param.N == 1) ? 1 : -1 }

var startX = { var.sX + var.dirX * var.surfaceClearance }
var targetX = { var.sX - var.dirX * var.overtravel }

var startY = { var.sY + var.dirY * var.cornerClearance }
var targetY = { var.sY - var.dirY * var.overtravel }

; Surface 1, Point 1
set var.surface1[0][0][0] = { var.startX }
set var.surface1[0][1][0] = { var.targetX }
set var.surface1[0][0][1] = { var.startY }
set var.surface1[0][1][1] = { var.startY }

; Surface 1, Point 2
; Only probe the second X point if we're in full mode
if { var.pFull }
    set var.startY = { var.sY + var.dirY * (var.fY - var.cornerClearance) }
    set var.surface1[1][0][0] = { var.startX }
    set var.surface1[1][1][0] = { var.targetX }
    set var.surface1[1][0][1] = { var.startY }
    set var.surface1[1][1][1] = { var.startY }

; Reverse directions for the second surface
set var.dirX = { -var.dirX }
set var.dirY = { -var.dirY }

set var.startX = { var.sX + var.dirX * var.cornerClearance }
set var.targetX = { var.sX - var.dirX * var.overtravel }

set var.startY = { var.sY + var.dirY * var.surfaceClearance }
set var.targetY = { var.sY - var.dirY * var.overtravel }

; Surface 2, Point 1
set var.surface2[0][0][0] = { var.startX }
set var.surface2[0][1][0] = { var.startX }
set var.surface2[0][0][1] = { var.startY }
set var.surface2[0][1][1] = { var.targetY }

; Surface 2, Point 2
; Only probe the second Y point if we're in full mode
if { var.pFull }
    set var.startX = { var.sX + var.dirX * (var.fX - var.cornerClearance) }
    set var.surface2[1][0][0] = { var.startX }
    set var.surface2[1][1][0] = { var.startX }
    set var.surface2[1][0][1] = { var.startY }
    set var.surface2[1][1][1] = { var.targetY }

; Probe the 2 corner surfaces
; Retract between each surface but
; not between each point
G6513 I{var.pID} D1 H0 P{var.surface1, var.surface2} S{var.safeZ}

var pSfc = { global.mosMI }

; pSfc contains a vector of surfaces which each have a
; vector of probe points, and possibly a surface angle.

; Since we probed 2 surfaces forming the corner, we need to
; calculate the corner position based on the intersection of
; the surfaces.

; If we're in quick mode, we just take the X value from the first
; probe point and the Y value from the second probe point.

; {
;   { # Surface 1
;       {
;           {235.5858,54.69131,-18.4560032}, # Point 1
;           {242.8524,110.8920,-18.4560032}  # Point 2
;       },
;       7.367285 # Angle
;   },
;   { # Surface 2
;       {
;           {246.9653,39.21858,-18.4560032}, # Point 1
;           {277.7650,35.21777,-18.4560032}  # Point 2
;       },
;       97.40112 # Angle
;   }
; }


; Corner position in quick mode
var cX = { var.pSfc[0][0][0][0] }
var cY = { var.pSfc[1][0][0][1] }

; Full mode (P=0) or unset
if { var.pFull }

    ; Surface points
    var pSfc1 = { var.pSfc[0][0] }
    var pSfc2 = { var.pSfc[1][0] }

    ; Surface angles
    var rSfc1 = { var.pSfc[0][2] }
    var rSfc2 = { var.pSfc[1][2] }

    ; Angle difference. This will be different depending on which corner
    ; is being probed. We add 2pi and take the modulo of pi to make sure
    ; this stays a positive value less than pi
    set global.mosWPCnrDeg[var.workOffset] = { degrees(mod(abs(var.rSfc1 - var.rSfc2) + 2 * pi, pi)) }

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

    var aR = { (var.fX > var.fY) ? var.rSfc1 - (pi/2) : var.rSfc2 }

    ; Reduce the angle to below +/- 45 degrees (pi/4 radians)
    while { var.aR > pi/4 || var.aR < -pi/4 }
        if { var.aR > pi/4 }
            set var.aR = { var.aR - pi/2 }
        elif { var.aR < -pi/4 }
            set var.aR = { var.aR + pi/2 }

    set global.mosWPDeg[var.workOffset] = { degrees(var.aR) }

    ; Extract the coordinates
    var x1 = { var.pSfc1[0][0] }
    var y1 = { var.pSfc1[0][1] }
    var x2 = { var.pSfc1[1][0] }
    var y2 = { var.pSfc1[1][1] }

    var x3 = { var.pSfc2[0][0] }
    var y3 = { var.pSfc2[0][1] }
    var x4 = { var.pSfc2[1][0] }
    var y4 = { var.pSfc2[1][1] }

    ; Calculate the gradients (slopes) of the lines
    var m1 = { (var.y2 - var.y1) / (var.x2 - var.x1) }
    var m2 = { (var.y4 - var.y3) / (var.x4 - var.x3) }

    ; Calculate the y-intercepts of the lines
    var c1 = { !isnan(var.m1) ? var.y1 - (var.m1 * var.x1) : 0 }
    var c2 = { !isnan(var.m2) ? var.y3 - (var.m2 * var.x3) : 0 }

    var xIntersect = { null }
    var yIntersect = { null }

    ; Calculate the intersection point (x, y)
    if { isnan(var.m1) || isnan(var.m2) }
        ; One of the lines is vertical
        set var.xIntersect = { isnan(var.m1) ? var.x1 : var.x3 }
        set var.yIntersect = { isnan(var.m1) ? (var.m2 * var.xIntersect + var.c2) : (var.m1 * var.xIntersect + var.c1) }
    elif { var.m1 == 0 || var.m2 == 0 }
        ; One of the lines is horizontal
        set var.yIntersect = { var.m1 == 0 ? var.y1 : var.y3 }
        set var.xIntersect = { var.m1 == 0 ? ((var.yIntersect - var.c2) / var.m2) : ((var.yIntersect - var.c1) / var.m1) }
    else
        ; General case
        set var.xIntersect = { (var.c2 - var.c1) / (var.m1 - var.m2) }
        set var.yIntersect = { (var.m1 * var.xIntersect) + var.c1 }

    ; RRF does weird things when given NaN values.
    if { isnan(var.xIntersect) || isnan(var.yIntersect) || var.xIntersect == null || var.yIntersect == null }
        abort { "Could not calculate intersection point!" }

    ; Set the corner position
    set var.cX = { var.xIntersect }
    set var.cY = { var.yIntersect }

    ; Calculate the center of the workpiece based on the corner position,
    ; the width and height of the workpiece and the rotation.

    var cDistX = { (var.fX/2) * cos(-var.aR) - (var.fY/2) * sin(-var.aR) }
    var cDistY = { (var.fX/2) * sin(-var.aR) + (var.fY/2) * cos(-var.aR) }

    var ctrX = { var.cX }
    var ctrY = { var.cY }

    if { param.N == 0 }
        set var.ctrX = { var.ctrX + var.cDistX }
        set var.ctrY = { var.ctrY + var.cDistY }
    elif { param.N == 1 }
        set var.ctrX = { var.ctrX - var.cDistX }
        set var.ctrY = { var.ctrY + var.cDistY }
    elif { param.N == 2 }
        set var.ctrX = { var.ctrX - var.cDistX }
        set var.ctrY = { var.ctrY - var.cDistY }
    elif { param.N == 3 }
        set var.ctrX = { var.ctrX + var.cDistX }
        set var.ctrY = { var.ctrY - var.cDistY }

    set global.mosWPCtrPos[var.workOffset] = { var.ctrX, var.ctrY }

    ; If running in full mode, operator provided approximate width and
    ; height values of the workpiece. Assign these to the global
    ; variables for the workpiece width and height.
    ; This assumes that the workpiece is rectangular.
    set global.mosWPDims[var.workOffset] = { var.fX, var.fY }

else
    ; Assume corner angle is 90 if we only probed one point
    ; per surface.
    set global.mosWPCnrDeg[var.workOffset] = { 90 }

; Set corner position
set global.mosWPCnrPos[var.workOffset] = { var.cX, var.cY }

; Set corner number
set global.mosWPCnrNum[var.workOffset] = { param.N }

; Make sure we're at the safeZ height
G6550 I{var.pID} Z{var.safeZ}

; Move above the corner position
G6550 I{var.pID} X{var.cX} Y{var.cY}

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}
    echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " X,Y origin to " ^ global.mosCornerNames[param.N] ^ " corner." }

; Set WCS origin to the probed corner
G10 L2 P{var.wcsNumber} X{var.cX} Y{var.cY}