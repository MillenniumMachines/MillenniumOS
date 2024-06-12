; G6502.1.g: RECTANGLE POCKET - EXECUTE
;
; Probe the X and Y edges of a rectangular pocket.
; Calculate the dimensions of the pocket and set the
; WCS origin to the probed center of the pocket, if requested.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 1 || param.W > limits.workplaces) }
    abort { "WCS number (W..) must be between 1 and " ^ limits.workplaces ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.H) || !exists(param.I) }
    abort { "Must provide an approximate width and length using H and I parameters!" }

var wpNum = { exists(param.W) && param.W != null ? param.W : limits.workplaces }

var probeId = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Reset stored values that we're going to overwrite -
; center, dimensions and rotation
M4010 W{var.wpNum} R49

; Store our own safe Z position as the current position. We return to
; this position where necessary to make moves across the workpiece to
; the next probe point.
; We do this _after_ any switch to the touch probe, because while the
; original position may have been safe with a different tool installed,
; the touch probe may be longer. After a tool change the spindle
; will be parked, so essentially our safeZ is at the parking location.
var safeZ = { move.axes[2].machinePosition }

; J = start position X
; K = start position Y
; L = start position Z - our probe height
; H = approximate width of pocket in X
; I = approximate length of pocket in Y

; Approximate center of pocket
var sX   = { param.J }
var sY   = { param.K }
var sZ   = { param.L }

; Width and Height of pocket
var fW   = { param.H }
var fL   = { param.I }

; Half of width and height of pocket, used in
; lots of calculations so stored here.
var hW   = { var.fW/2 }
var hL   = { var.fL/2 }

; Tool Radius is the first entry for each value in
; our extended tool table.

; Apply tool radius to clearance. We want to make sure
; the surface of the tool and the workpiece are the
; clearance distance apart, rather than less than that.
var clearance = { (exists(param.T) ? param.T : global.mosCL) + ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Check that the clearance distance isn't
; higher than the width or height of the pocket.
; Since we use the clearance distance to choose
; how far along each surface we should probe from
; the expected corners, a clearance higher than
; the width or height would mean we would try to
; probe off the edge of the pocket.
if { var.clearance >= var.fW || var.clearance >= var.fL }
    abort { "Clearance distance is higher than the width or height of the rectangle pocket! Cannot probe." }

; The overtravel distance does not have the same
; requirement, as it is only used to adjust the
; probe target towards or away from the target
; surface rather.

; Commented due to memory limitations
; M7500 S{"Distance Modifiers adjusted for Tool Radius - Clearance=" ^ var.clearance ^ " Overtravel=" ^ var.overtravel }

; We can calculate the squareness of the pocket by probing outwards
; towards each edge and calculating an angle.
; Our start position is inwards by the clearance distance from
; both ends of the face.
; We need 8 probes to calculate the squareness of the pocket (2 for each edge).

var pX = { null, null, null, null }
var pY = { null, null, null, null }

; We use D1 on all of our probe points. This means that the probe
; macro does not automatically move back to its' safe Z position after
; probing, and we must manage this ourselves.

; Move into pocket at probing depth
G6550 I{var.probeId} Z{param.L}

; Move outwards on X first
G6550 I{var.probeId} X{(var.sX - var.hW + var.clearance)}

; First probe point - left edge, inwards from front face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX - var.hW + var.clearance)} K{(var.sY - var.hL + var.clearance)} L{param.L} X{(var.sX - var.hW - var.overtravel)}
set var.pX[0] = { global.mosPCX }

; Return to our starting position
G6550 I{var.probeId} X{(var.sX - var.hW + var.clearance)}

; Second probe point - left edge, inwards from rear face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX - var.hW + var.clearance)} K{(var.sY + var.hL - var.clearance)} L{param.L} X{(var.sX - var.hW - var.overtravel)}
set var.pX[1] = { global.mosPCX }

; Return to our starting position
G6550 I{var.probeId} X{(var.sX - var.hW + var.clearance)}

; No need to raise probe as we are in a pocket

; NOTE: Second surface probes from the rear first
; as this shortens the movement distance.

; Third probe point - right edge, inwards from rear face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX + var.hW - var.clearance)} K{(var.sY + var.hL - var.clearance)} L{param.L} X{(var.sX + var.hW + var.overtravel)}
set var.pX[2] = { global.mosPCX }

; Return to our starting position
G6550 I{var.probeId} X{(var.sX + var.hW - var.clearance)}

; Fourth probe point - right edge, inwards from front face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 J{(var.sX + var.hW - var.clearance)} K{(var.sY - var.hL + var.clearance)} L{param.L} X{(var.sX + var.hW + var.overtravel)}
set var.pX[3] = { global.mosPCX }

; Return to our starting position.
G6550 I{var.probeId} X{(var.sX + var.hW - var.clearance)}

; Okay, we now have 2 'lines' representing the X edges of the pocket.
; Line 1: var.pX[0] to var.pX[1]
; Line 2: var.pX[2] to var.pX[3]

; These lines are not necessarily perpendicular to the X axis if the
; pocket or the vice is not trammed correctly with the probe.

; We may be able to compensate for this by applying a G68 co-ordinate
; rotation.

; They may also not be parallel to each other if the pocket itself
; is not completely square.

; If the lines are not parallel, we should abort if the angle is
; higher than a certain threshold.

; Calculate the angle of each line.
; We can calculate the angle of a line using the arctan of the slope.
; The slope of a line is the change in Y divided by the change in X.

; Our variable names are a bit confusing here, but we are using
; the X axis to probe the Y edges of the pocket, so we are calculating
; the angle of the Y edges of the pocket.

; Calculate the angle difference of each line.
var aX1 = { atan((var.pX[1] - var.pX[0]) / (var.fL - (2*var.clearance))) }
var aX2 = { atan((var.pX[2] - var.pX[3]) / (var.fL - (2*var.clearance))) }
var xAngleDiff = { degrees(abs(var.aX1 - var.aX2)) }

; Commented due to memory limitations
; M7500 S{"X Surface Angle difference: " ^ var.xAngleDiff ^ " Threshold: " ^ global.mosAngleTol }

; If the angle difference is greater than a certain threshold, abort.
; We do this because the below code makes assumptions about the
; squareness of the pocket, and if these assumptions are not correct
; then there is a chance we could damage the probe or incorrectly
; calculate dimensions or centerpoint.
if { var.xAngleDiff > global.mosAngleTol }
    abort { "Rectangular pocket surfaces on X axis are not parallel - this pocket does not appear to be square. (" ^ var.xAngleDiff ^ " degrees difference in surface angle and our threshold is " ^ global.mosAngleTol ^ " degrees!)" }

; Now we have validated that the pocket is square in X, we need to calculate
; the real center position of the pocket so we can probe the Y surfaces.

; Our midpoint for each line is the average of the 2 points, so
; we can just add all of the points together and divide by 4.
set var.sX = { (var.pX[0] + var.pX[1] + var.pX[2] + var.pX[3]) / 4 }
set global.mosWPCtrPos[var.wpNum][0] = { var.sX }

; Use the recalculated center of the pocket to probe Y surfaces.

; Move outwards on X first. This _looks_ like a no-op because it
; is the same as the previous G6550, but var.sX has been updated with
; the _calculated_ center of the pocket in X, so we can now be more
; accurate with out offsets from each end of the Y surfaces.
G6550 I{var.probeId} X{(var.sX + var.hW - var.clearance)}

; Probe Y surfaces

; First probe point - front edge, inwards from right face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY - var.hL + var.clearance)} J{(var.sX + var.hW - var.clearance)} L{param.L} Y{(var.sY - var.hL - var.overtravel)}
set var.pY[0] = { global.mosPCY }

; Return to our starting position
G6550 I{var.probeId} Y{(var.sY - var.hL + var.clearance)}

; Second probe point - front edge, inwards from left face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY - var.hL + var.clearance)} J{(var.sX - var.hW + var.clearance)} L{param.L} Y{(var.sY - var.hL - var.overtravel)}
set var.pY[1] = { global.mosPCY }

; Return to our starting position.
; Again, no need to raise probe as we are in a pocket.
G6550 I{var.probeId} Y{(var.sY - var.hL + var.clearance)}

; Third probe point - rear edge, inwards from left face by clearance distance
; towards the face plus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY + var.hL - var.clearance)} J{(var.sX - var.hW + var.clearance)} L{param.L} Y{(var.sY + var.hL + var.overtravel)}
set var.pY[2] = { global.mosPCY }

; Return to our starting position
G6550 I{var.probeId} Y{(var.sY + var.hL - var.clearance)}

; Fourth probe point - rear edge, inwards from right face by clearance distance
; towards the face minus overtravel distance.
G6512 I{var.probeId} D1 K{(var.sY + var.hL - var.clearance)} J{(var.sX + var.hW - var.clearance)} L{param.L} Y{(var.sY + var.hL + var.overtravel)}
set var.pY[3] = { global.mosPCY }

; Return to our starting position.
G6550 I{var.probeId} Y{(var.sY + var.hL - var.clearance)}


; Okay like before, we now have 2 'lines' representing the Y edges of the pocket.
; Line 1: var.pY[0] to var.pY[1]
; Line 2: var.pY[2] to var.pY[3]

; Calculate the angle of each line.
var aY1 = { atan((var.pY[1] - var.pY[0]) / (var.fW - (2*var.clearance))) }
var aY2 = { atan((var.pY[2] - var.pY[3]) / (var.fW - (2*var.clearance))) }
var yAngleDiff = { degrees(abs(var.aY1 - var.aY2)) }

; Commented due to memory limitations
; M7500 S{"Y Surface Angle difference: " ^ var.yAngleDiff ^ " Threshold: " ^ global.mosAngleTol }

; Abort if the angle difference is greater than a certain threshold like
; we did for the X axis.
if { var.yAngleDiff > global.mosAngleTol }
    abort { "Rectangular pocket surfaces on Y axis are not parallel - this pocket does not appear to be square. (" ^ var.yAngleDiff ^ " degrees difference in surface angle and our threshold is " ^ global.mosAngleTol ^ " degrees!)" }

; Commented due to memory limitations
; M7500 S{"Surface Angles X1=" ^ degrees(var.aX1) ^ " X2=" ^ degrees(var.aX2) ^ " Y1=" ^ degrees(var.aY1) ^ " Y2=" ^ degrees(var.aY2) }

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

var cornerAngleError = { degrees(var.aX1 - var.aY1) }

; We report the corner angle around 90 degrees
set global.mosWPCnrDeg[var.wpNum] = { 90 + var.cornerAngleError }

; Commented due to memory limitations
; M7500 S{"Rectangle Pocket Corner Angle Error: " ^ var.cornerAngleError }

; Abort if the corner angle is greater than a certain threshold.
if { (var.cornerAngleError > global.mosAngleTol) }
    abort { "Rectangular pocket corner angle is not 90 degrees - this pocket does not appear to be square. (" ^ var.cornerAngleError ^ " degrees difference in corner angle and our threshold is " ^ global.mosAngleTol ^ " degrees!)" }

; Calculate Y centerpoint as before.
set var.sY = { (var.pY[0] + var.pY[1] + var.pY[2] + var.pY[3]) / 4 }
set global.mosWPCtrPos[var.wpNum][1] = { var.sY }

; We can now calculate the actual dimensions of the pocket.
; The dimensions are the difference between the average of each
; pair of points of each line.
set global.mosWPDims[var.wpNum][0] = { ((var.pX[2] + var.pX[3]) / 2) - ((var.pX[0] + var.pX[1]) / 2) }
set global.mosWPDims[var.wpNum][1] = { ((var.pY[2] + var.pY[3]) / 2) - ((var.pY[0] + var.pY[1]) / 2) }

; Set the global error in dimensions
; This can be used by other macros to configure the touch probe deflection.
set global.mosWPDimsErr[var.wpNum] = { abs(var.fW - global.mosWPDims[var.wpNum][0]), abs(var.fL - global.mosWPDims[var.wpNum][1]) }

; Move to the calculated center of the pocket
G6550 I{var.probeId} X{var.sX} Y{var.sY}

; Move to the safe Z height
G6550 I{var.probeId} I{var.probeId} Z{var.safeZ}

; Calculate the rotation of the pocket against the X axis.
; After the checks above, we know the pocket is rectangular,
; within our threshold for squareness, but it might still be
; rotated in relation to our axes. At this point, the angle
; of the entire pocket's rotation can be assumed to be the same
; as the angle of the first X line.

; Calculate the slope and angle of the first X line.
set global.mosWPDeg[var.wpNum] = { degrees(var.aX1) }

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.wpNum}

; Set WCS origin to the probed center, if requested
if { exists(param.W) && param.W != null }
    echo { "MillenniumOS: Setting WCS " ^ param.W ^ " X,Y origin to center of rectangle pocket." }
    G10 L2 P{param.W} X{var.sX} Y{var.sY}