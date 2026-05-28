; G6503.1.g: RECTANGLE BLOCK - EXECUTE
;
; Probe the X and Y edges of a rectangular block.
; Calculate the dimensions of the block and set the
; WCS origin to the probed center of the block, if requested.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.Z) }
    abort { "Must provide a probe position using the Z parameter!" }

if { !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate width and length using H and I parameters!" }

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

; Probe mode defaults to (0=Full)
var pFull = { exists(param.Q) ? param.Q == 0 : true }

; Increment the probe surface and point totals for status reporting.
; Full mode probes 2 points per surface (8 total), quick mode probes
; 1 point per surface (4 total).
set global.mosPRST = { global.mosPRST + 4 }
set global.mosPRPT = { global.mosPRPT + (var.pFull ? 8 : 4) }

var pID = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    abort { "Must run T" ^ global.mosPTID ^ " to select the probe tool before probing!" }

; Reset stored values that we're going to overwrite -
; center, dimensions and rotation
M5010 W{var.workOffset} R49

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
; L = start position Z
; Z = our probe height (absolute)
; H = approximate width of block in X
; I = approximate length of block in Y

; Approximate center of block
var sX   = { param.J }
var sY   = { param.K }

; Width and Height of block
var fW   = { param.H }
var fL   = { param.I }

; Half of width and height of block, used in
; lots of calculations so stored here.
var hW   = { var.fW/2 }
var hL   = { var.fL/2 }

; Tool Radius is the first entry for each value in
; our extended tool table.

; Apply tool radius to surface clearance. We want to
; make sure the surface of the tool and the workpiece
; are the clearance distance apart, rather than less
; than that.
var surfaceClearance = { ((!exists(param.T) || param.T == null) ? global.mosCL : param.T) + ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Default corner clearance to the normal clearance
; distance, but allow it to be overridden if necessary.
; Only used in full mode; quick mode probes at the centre
; of each surface and ignores corner clearance.
var cornerClearance = { var.pFull ? ((!exists(param.C) || param.C == null) ? ((!exists(param.T) || param.T == null) ? global.mosCL : param.T) : param.C) : 0 }

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Check that 2 times the clearance distance isn't
; higher than the width or height of the block.
; Since we use the clearance distance to choose
; how far along each surface we should probe from
; the expected corners, a clearance higher than
; the width or height would mean we would try to
; probe off the edge of the block.
; Only relevant in full mode.
if { var.pFull && (var.cornerClearance >= var.hW || var.cornerClearance >= var.hL) }
    abort { "Corner clearance distance is more than half of the width or height of the block! Cannot probe." }

; The overtravel distance does not have the same
; requirement, as it is only used to adjust the
; probe target towards or away from the target
; surface rather.

; In full mode we calculate squareness of the block by probing inwards
; from each edge and calculating an angle. The probe positions are
; then offset inwards by the corner clearance from each end of the face.
; In quick mode we probe a single point at the centre of each surface
; and trust the operator that the block is aligned with the axes.

; Calculate the probe positions for the surfaces
var points = { vector(2 - (var.pFull ? 0 : 1), {{null, null, param.Z}, {null, null, param.Z}}) }

var surface1 = { var.points }
var surface2 = { var.points }

; ---- X surfaces ----

; Surface 1, Point 1 (left surface)
set var.surface1[0][0][0] = { var.sX - var.hW - var.surfaceClearance }
set var.surface1[0][1][0] = { var.sX - var.hW + var.overtravel }
set var.surface1[0][0][1] = { var.pFull ? var.sY - var.hL + var.cornerClearance : var.sY }
set var.surface1[0][1][1] = { var.pFull ? var.sY - var.hL + var.cornerClearance : var.sY }

; Surface 2, Point 1 (right surface)
set var.surface2[0][0][0] = { var.sX + var.hW + var.surfaceClearance }
set var.surface2[0][1][0] = { var.sX + var.hW - var.overtravel }
set var.surface2[0][0][1] = { var.pFull ? var.sY + var.hL - var.cornerClearance : var.sY }
set var.surface2[0][1][1] = { var.pFull ? var.sY + var.hL - var.cornerClearance : var.sY }

if { var.pFull }
    ; Surface 1, Point 2
    set var.surface1[1][0][0] = { var.sX - var.hW - var.surfaceClearance }
    set var.surface1[1][1][0] = { var.sX - var.hW + var.overtravel }
    set var.surface1[1][0][1] = { var.sY + var.hL - var.cornerClearance }
    set var.surface1[1][1][1] = { var.sY + var.hL - var.cornerClearance }

    ; Surface 2, Point 2
    set var.surface2[1][0][0] = { var.sX + var.hW + var.surfaceClearance }
    set var.surface2[1][1][0] = { var.sX + var.hW - var.overtravel }
    set var.surface2[1][0][1] = { var.sY - var.hL + var.cornerClearance }
    set var.surface2[1][1][1] = { var.sY - var.hL + var.cornerClearance }

; Probe the 2 X surfaces
; Retract between each surface but
; not between each point
G6513 I{var.pID} D1 H0 P{var.surface1, var.surface2} S{var.safeZ}

var pSfcX = { global.mosMI }

; In full mode, validate that the X surfaces are parallel.
if { var.pFull }
    ; Surface angles
    var dXAngleDiff = { degrees(abs(mod(var.pSfcX[0][2] - var.pSfcX[1][2], pi))) }

    ; Normalise the angle difference to be between 0 and 90 degrees
    if { var.dXAngleDiff > pi/2 }
        set var.dXAngleDiff = { pi - var.dXAngleDiff }

    ; Make sure X surfaces are suitably parallel
    if { var.dXAngleDiff > global.mosAngleTol }
        abort { "Rectangular block surfaces on X axis are not parallel (" ^ var.dXAngleDiff ^ " > " ^ global.mosAngleTol ^ ") - this block does not appear to be square." }

; Calculate the real centre of the block in X so we can probe the Y
; surfaces. In full mode we use the midpoint of the two probed points
; on each surface; in quick mode we use the single probed point.
var leftMidpoint  = { var.pFull ? (var.pSfcX[0][0][0][0] + var.pSfcX[0][0][1][0]) / 2 : var.pSfcX[0][0][0][0] }
var rightMidpoint = { var.pFull ? (var.pSfcX[1][0][0][0] + var.pSfcX[1][0][1][0]) / 2 : var.pSfcX[1][0][0][0] }

; Calculate the average of the left and right surface midpoints
set var.sX = { (var.leftMidpoint + var.rightMidpoint) / 2 }

; ---- Y surfaces ----
; Use the recalculated center of the block to probe Y surfaces.

; Surface 1, Point 1 (bottom surface)
set var.surface1[0][0][0] = { var.pFull ? var.sX + var.hW - var.cornerClearance : var.sX }
set var.surface1[0][1][0] = { var.pFull ? var.sX + var.hW - var.cornerClearance : var.sX }
set var.surface1[0][0][1] = { var.sY - var.hL - var.surfaceClearance }
set var.surface1[0][1][1] = { var.sY - var.hL + var.overtravel }

; Surface 2, Point 1 (top surface)
set var.surface2[0][0][0] = { var.pFull ? var.sX - var.hW + var.cornerClearance : var.sX }
set var.surface2[0][1][0] = { var.pFull ? var.sX - var.hW + var.cornerClearance : var.sX }
set var.surface2[0][0][1] = { var.sY + var.hL + var.surfaceClearance }
set var.surface2[0][1][1] = { var.sY + var.hL - var.overtravel }

if { var.pFull }
    ; Surface 1, Point 2
    set var.surface1[1][0][0] = { var.sX - var.hW + var.cornerClearance }
    set var.surface1[1][1][0] = { var.sX - var.hW + var.cornerClearance }
    set var.surface1[1][0][1] = { var.sY - var.hL - var.surfaceClearance }
    set var.surface1[1][1][1] = { var.sY - var.hL + var.overtravel }

    ; Surface 2, Point 2
    set var.surface2[1][0][0] = { var.sX + var.hW - var.cornerClearance }
    set var.surface2[1][1][0] = { var.sX + var.hW - var.cornerClearance }
    set var.surface2[1][0][1] = { var.sY + var.hL + var.surfaceClearance }
    set var.surface2[1][1][1] = { var.sY + var.hL - var.overtravel }

; Probe the 2 Y surfaces
G6513 I{var.pID} D1 H0 P{var.surface1, var.surface2} S{var.safeZ}

var pSfcY = { global.mosMI }

; In full mode, validate parallelism and corner perpendicularity, and
; record the corner angle. In quick mode, assume a perfectly square
; corner.
if { var.pFull }
    ; Surface angles
    var dYAngleDiff = { degrees(abs(mod(var.pSfcY[0][2] - var.pSfcY[1][2], pi))) }

    ; Normalise the angle difference to be between 0 and 90 degrees
    if { var.dYAngleDiff > pi/2 }
        set var.dYAngleDiff = { pi - var.dYAngleDiff }

    ; Make sure Y surfaces are suitably parallel
    if { var.dYAngleDiff > global.mosAngleTol }
        abort { "Rectangular block surfaces on Y axis are not parallel (" ^ var.dYAngleDiff ^ " > " ^ global.mosAngleTol ^ ") - this block does not appear to be square." }

    ; Calculate the angle of the corner between X line 1 and Y line 1.
    ; This is the angle of the front-left corner of the block.
    ; The angles are between the line and their respective axis, so
    ; a perfect 90 degree corner with completely squared machine axes
    ; would report an error of 0 degrees.
    var cornerAngleError = { abs(90 - degrees(abs(mod(var.pSfcX[0][2] - var.pSfcY[0][2], pi)))) }

    ; Make sure the corner angle is suitably perpendicular
    if { var.cornerAngleError > global.mosAngleTol }
        abort { "Rectangular block corner angle is not perpendicular (" ^ var.cornerAngleError ^ " > " ^ global.mosAngleTol ^ ") - this block does not appear to be square." }

    ; We report the corner angle around 90 degrees
    set global.mosWPCnrDeg[var.workOffset] = { 90 + var.cornerAngleError }
else
    ; Assume a square corner in quick mode.
    set global.mosWPCnrDeg[var.workOffset] = { 90 }

; Calculate the centre Y from the probed Y surfaces.
var bottomMidpoint = { var.pFull ? (var.pSfcY[0][0][0][1] + var.pSfcY[0][0][1][1]) / 2 : var.pSfcY[0][0][0][1] }
var topMidpoint    = { var.pFull ? (var.pSfcY[1][0][0][1] + var.pSfcY[1][0][1][1]) / 2 : var.pSfcY[1][0][0][1] }

; Calculate center Y as midpoint between bottom and top surfaces
set var.sY = { (var.bottomMidpoint + var.topMidpoint) / 2 }

; Set the centre of the block
set global.mosWPCtrPos[var.workOffset] = { var.sX, var.sY }

; Calculate the actual dimensions of the block from the probed
; surface midpoints.
set global.mosWPDims[var.workOffset][0] = { abs(var.leftMidpoint - var.rightMidpoint) }
set global.mosWPDims[var.workOffset][1] = { abs(var.bottomMidpoint - var.topMidpoint) }

; Set the global error in dimensions
; This can be used by other macros to configure the touch probe deflection.
set global.mosWPDimsErr[var.workOffset] = { abs(var.fW - global.mosWPDims[var.workOffset][0]), abs(var.fL - global.mosWPDims[var.workOffset][1]) }

; Make sure we're at the safeZ height
G6550 I{var.pID} Z{var.safeZ}

; Move to the calculated center of the block
G6550 I{var.pID} X{var.sX} Y{var.sY}

; Calculate the rotation of the block against the X axis (full mode only).
; After the checks above, we know the block is rectangular, within our
; threshold for squareness, but it might still be rotated in relation to
; our axes. The angle of the entire block can be assumed to be the angle
; of the first surface on the longest edge of the block.
; We need to normalise the rotation to be within +- 45 degrees.
; Quick mode skips this and leaves the stored rotation at its default,
; so M5011 will not prompt for rotation compensation.
if { var.pFull }
    var aR = { var.pSfcX[0][2] }

    ; Reduce the angle to below +/- 45 degrees (pi/4 radians)
    while { var.aR > pi/4 || var.aR < -pi/4 }
        if { var.aR > pi/4 }
            set var.aR = { var.aR - pi/2 }
        elif { var.aR < -pi/4 }
            set var.aR = { var.aR + pi/2 }

    set global.mosWPDeg[var.workOffset] = { degrees(var.aR) }

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}
    echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " X,Y origin to the center of the rectangle block." }

; Set WCS origin to the probed center
G10 L2 P{var.wcsNumber} X{var.sX} Y{var.sY}
