; G6502.1.g: RECTANGLE POCKET - EXECUTE
;
; Probe the X and Y edges of a rectangular pocket.
; Calculate the dimensions of the pocket and set the
; WCS origin to the probed center of the pocket, if requested.

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

; Increment the probe surface and point totals for status reporting
set global.mosPRST = { global.mosPRST + 4 }
set global.mosPRPT = { global.mosPRPT + 8 }

var pID = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    abort { "Must run T" ^ global.mosPTID ^ " to select the probe tool before probing!" }

; Reset stored values that we're going to overwrite -
; center, dimensions and rotation
M5010 W{var.workOffset} R49

; Get current machine position on Z
M5000 P1 I2

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
; H = approximate width of pocket in X
; I = approximate length of pocket in Y

; Approximate center of pocket
var sX   = { param.J }
var sY   = { param.K }

; Width and Height of pocket
var fW   = { param.H }
var fL   = { param.I }

; Half of width and height of pocket, used in
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
var cornerClearance = { (!exists(param.C) || param.C == null) ? ((!exists(param.T) || param.T == null) ? global.mosCL : param.T) : param.C }

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Check that 2 times the clearance distance isn't
; higher than the width or height of the pocket.
; Since we use the clearance distance to choose
; how far along each surface we should probe from
; the expected corners, a clearance higher than
; the width or height would mean we would try to
; probe off the edge of the pocket.
if { var.cornerClearance >= var.hW || var.cornerClearance >= var.hL }
    abort { "Corner clearance distance is more than half of the width or height of the pocket! Cannot probe." }

; The overtravel distance does not have the same
; requirement, as it is only used to adjust the
; probe target towards or away from the target
; surface rather.

; We can calculate the squareness of the pocket by probing inwards
; from each edge and calculating an angle.
; Our start position is then inwards by the clearance distance from
; both ends of the face.
; We need 8 probes to calculate the squareness of the pocket (2 for each edge).

; Quick mode not implemented yet
var pFull = { true }

; Calculate the probe positions for the surfaces
var points = { vector(2 - (var.pFull ? 0 : 1), {{null, null, param.Z}, {null, null, param.Z}}) }

var surface1 = { var.points }
var surface2 = { var.points }

; Surface 1, Point 1
set var.surface1[0][0][0] = { var.sX - var.hW + var.surfaceClearance }
set var.surface1[0][1][0] = { var.sX - var.hW - var.overtravel }
set var.surface1[0][0][1] = { var.sY - var.hL + var.cornerClearance }
set var.surface1[0][1][1] = { var.sY - var.hL + var.cornerClearance }

; Surface 1, Point 2
set var.surface1[1][0][0] = { var.sX - var.hW + var.surfaceClearance }
set var.surface1[1][1][0] = { var.sX - var.hW - var.overtravel }
set var.surface1[1][0][1] = { var.sY + var.hL - var.cornerClearance }
set var.surface1[1][1][1] = { var.sY + var.hL - var.cornerClearance }

; Surface 2, Point 1
set var.surface2[0][0][0] = { var.sX + var.hW - var.surfaceClearance }
set var.surface2[0][1][0] = { var.sX + var.hW + var.overtravel }
set var.surface2[0][0][1] = { var.sY + var.hL - var.cornerClearance }
set var.surface2[0][1][1] = { var.sY + var.hL - var.cornerClearance }

; Surface 2, Point 2
set var.surface2[1][0][0] = { var.sX + var.hW - var.surfaceClearance }
set var.surface2[1][1][0] = { var.sX + var.hW + var.overtravel }
set var.surface2[1][0][1] = { var.sY - var.hL + var.cornerClearance }
set var.surface2[1][1][1] = { var.sY - var.hL + var.cornerClearance }

; Probe the 2 X surfaces
; Do not retract between probe points
G6513 I{var.pID} D1 H1 P{var.surface1, var.surface2} S{var.safeZ}

var pSfcX = { global.mosMI }

; Surface angles
var dXAngleDiff = { degrees(abs(mod(var.pSfcX[0][2] - var.pSfcX[1][2], pi))) }

; Normalise the angle difference to be between 0 and 90 degrees
if { var.dXAngleDiff > pi/2 }
    set var.dXAngleDiff = { pi - var.dXAngleDiff }

; Make sure X surfaces are suitably parallel
if { var.dXAngleDiff > global.mosAngleTol }
    abort { "Rectangular pocket surfaces on X axis are not parallel (" ^ var.dXAngleDiff ^ " > " ^ global.mosAngleTol ^ ") - this pocket does not appear to be square." }

; Now we have validated that the pocket is square in X, we need to calculate
; the real center position of the pocket so we can probe the Y surfaces.

; Our midpoint for each line is the average of the 2 points, so
; we can just add all of the points together and divide by 4.

set var.sX = { (var.pSfcX[0][0][0][0] + var.pSfcX[0][0][1][0] + var.pSfcX[1][0][0][0] + var.pSfcX[1][0][1][0]) / 4 }

; Use the recalculated center of the pocket to probe Y surfaces.

; Surface 1, Point 1
set var.surface1[0][0][0] = { var.sX + var.hW - var.cornerClearance }
set var.surface1[0][1][0] = { var.sX + var.hW - var.cornerClearance }
set var.surface1[0][0][1] = { var.sY - var.hL + var.surfaceClearance }
set var.surface1[0][1][1] = { var.sY - var.hL - var.overtravel }

; Surface 1, Point 2
set var.surface1[1][0][0] = { var.sX - var.hW + var.cornerClearance }
set var.surface1[1][1][0] = { var.sX - var.hW + var.cornerClearance }
set var.surface1[1][0][1] = { var.sY - var.hL + var.surfaceClearance }
set var.surface1[1][1][1] = { var.sY - var.hL - var.overtravel }

; Surface 2, Point 1
set var.surface2[0][0][0] = { var.sX - var.hW + var.cornerClearance }
set var.surface2[0][1][0] = { var.sX - var.hW + var.cornerClearance }
set var.surface2[0][0][1] = { var.sY + var.hL - var.surfaceClearance }
set var.surface2[0][1][1] = { var.sY + var.hL + var.overtravel }

; Surface 2, Point 2
set var.surface2[1][0][0] = { var.sX + var.hW - var.cornerClearance }
set var.surface2[1][1][0] = { var.sX + var.hW - var.cornerClearance }
set var.surface2[1][0][1] = { var.sY + var.hL - var.surfaceClearance }
set var.surface2[1][1][1] = { var.sY + var.hL + var.overtravel }

; Probe the 2 Y surfaces
G6513 I{var.pID} D1 H0 P{var.surface1, var.surface2} S{var.safeZ}

var pSfcY = { global.mosMI }

; Surface angles
var dYAngleDiff = { degrees(abs(mod(var.pSfcY[0][2] - var.pSfcY[1][2], pi))) }

; Normalise the angle difference to be between 0 and 90 degrees
if { var.dYAngleDiff > pi/2 }
    set var.dYAngleDiff = { pi - var.dYAngleDiff }

; Make sure X surfaces are suitably parallel
if { var.dYAngleDiff > global.mosAngleTol }
    abort { "Rectangular pocket surfaces on Y axis are not parallel (" ^ var.dYAngleDiff ^ " > " ^ global.mosAngleTol ^ ") - this pocket does not appear to be square." }

; Okay, we have now validated that the pocket surfaces are square in both X and Y.
; But this does not mean they are square to each other, so we need to calculate
; the angle of one corner between 2 lines and check it meets our threshold.
; If one of the corners is square, then the other corners must also be square -
; because the probed surfaces are sufficiently parallel.

; Calculate the angle of the corner between X line 1 and Y line 1.
; This is the angle of the front-left corner of the pocket.
; The angles are between the line and their respective axis, so
; a perfect 90 degree corner with completely squared machine axes
; would report an error of 0 degrees.

var cornerAngleError = { abs(90 - degrees(abs(mod(var.pSfcX[0][2] - var.pSfcY[0][2], pi)))) }

; Make sure the corner angle is suitably perpendicular
if { var.cornerAngleError > global.mosAngleTol }
    abort { "Rectangular pocket corner angle is not perpendicular (" ^ var.cornerAngleError ^ " > " ^ global.mosAngleTol ^ ") - this pocket does not appear to be square." }

; We report the corner angle around 90 degrees
set global.mosWPCnrDeg[var.workOffset] = { 90 + var.cornerAngleError }

; Abort if the corner angle is greater than a certain threshold.
if { (var.cornerAngleError > global.mosAngleTol) }
    abort { "Rectangular pocket corner angle is not perpendicular (" ^ var.cornerAngleError ^ " > " ^ global.mosAngleTol ^ ") - this pocket does not appear to be square." }

; Calculate Y centerpoint
set var.sY = { (var.pSfcY[0][0][0][1] + var.pSfcY[0][0][1][1] + var.pSfcY[1][0][0][1] + var.pSfcY[1][0][1][1]) / 4 }

; Set the centre of the pocket
set global.mosWPCtrPos[var.workOffset] = { var.sX, var.sY }


; We can now calculate the actual dimensions of the pocket.
; The dimensions are the difference between the average of each
; pair of points of each line.
set global.mosWPDims[var.workOffset][0] = { ((var.pSfcX[0][0][0][0] + var.pSfcX[0][0][1][0]) / 2) - ((var.pSfcX[1][0][0][0] + var.pSfcX[1][0][1][0]) / 2) }
set global.mosWPDims[var.workOffset][1] = { ((var.pSfcY[0][0][0][1] + var.pSfcY[0][0][1][1]) / 2) - ((var.pSfcY[1][0][0][1] + var.pSfcY[1][0][1][1]) / 2) }

; Set the global error in dimensions
; This can be used by other macros to configure the touch probe deflection.
set global.mosWPDimsErr[var.workOffset] = { abs(var.fW - global.mosWPDims[var.workOffset][0]), abs(var.fL - global.mosWPDims[var.workOffset][1]) }

; Make sure we're at the safeZ height
G6550 I{var.pID} Z{var.safeZ}

; Move to the calculated center of the pocket
G6550 I{var.pID} X{var.sX} Y{var.sY}

; Calculate the rotation of the pocket against the X axis.
; After the checks above, we know the pocket is rectangular,
; within our threshold for squareness, but it might still be
; rotated in relation to our axes. At this point, the angle
; of the entire pocket's rotation can be assumed to be the angle
; of the first surface on the longest edge of the pocket.
; We need to normalise the rotation to be within +- 45 degrees

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
    echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " X,Y origin to the center of the rectangle pocket." }

; Set WCS origin to the probed center
G10 L2 P{var.wcsNumber} X{var.sX} Y{var.sY}