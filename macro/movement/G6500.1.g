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

if { !exists(param.H) }
    abort { "Must provide an approximate bore diameter using the H parameter!" }

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Probe ID
var pID = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Reset stored values that we're going to overwrite
; Reset center position, rotation and radius
M5010 W{var.workOffset} R37

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

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool <= limits.tools-1 && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; TODO: Validate minimum bore diameter we can probe based on
; dive height and back-off distance.

; We add the overtravel to the bore radius to give the user
; some leeway. If their estimate of the bore diameter is too
; small, then the probe will not activate and the operation
; will fail.
var bR = { (param.H / 2) + var.overtravel }

; Probe equally at 3 points around the bore, starting at 0
; degrees (3 o'clock) and moving anticlockwise.
var angle = { 2*pi / 3 }

var startPos = { param.J, param.K, param.L }

; Bore probes all use the same start position (operator-
; chosen center of the bore). These must be defined as 3
; separate surfaces, because surface angle makes no sense
; for a single circular surface.
var surfaces = { vector(3, {{var.startPos, null},}) }

; Set the target positions for each of the probe points
set var.surfaces[0][0][1] = { var.startPos[0] + var.bR, var.startPos[1], var.startPos[2] }
set var.surfaces[1][0][1] = { var.startPos[0] + var.bR * cos(var.angle), var.startPos[1] + var.bR * sin(var.angle), var.startPos[2] }
set var.surfaces[2][0][1] = { var.startPos[0] + var.bR * cos(2 * var.angle), var.startPos[1] + var.bR * sin(2 * var.angle), var.startPos[2] }

; Probe the bore surface
; Do not retract between probe points
G6513 I{var.pID} D1 H1 P{var.surfaces} S{var.safeZ}

var pSfc = { global.mosMI }

; Extract the coordinates of the three probe points
var x1 = { var.pSfc[0][0][0][0] }
var y1 = { var.pSfc[0][0][0][1] }

var x2 = { var.pSfc[1][0][0][0] }
var y2 = { var.pSfc[1][0][0][1] }

var x3 = { var.pSfc[2][0][0][0] }
var y3 = { var.pSfc[2][0][0][1] }

; Calculate the center of the circle passing through the three points
; This is essentially calculating 3 lines running through the midpoints
; of the chords between the points, and finding the intersection of those
; lines.
var A = { var.x1 * (var.y2 - var.y3) + var.x2 * (var.y3 - var.y1) + var.x3 * (var.y1 - var.y2) }
var B = { (var.x1 * var.x1 + var.y1 * var.y1) * (var.y3 - var.y2) + (var.x2 * var.x2 + var.y2 * var.y2) * (var.y1 - var.y3) + (var.x3 * var.x3 + var.y3 * var.y3) * (var.y2 - var.y1) }
var C = { (var.x1 * var.x1 + var.y1 * var.y1) * (var.x2 - var.x3) + (var.x2 * var.x2 + var.y2 * var.y2) * (var.x3 - var.x1) + (var.x3 * var.x3 + var.y3 * var.y3) * (var.x1 - var.x2) }
var D = { 2 * (var.x1 * (var.y2 - var.y3) + var.x2 * (var.y3 - var.y1) + var.x3 * (var.y1 - var.y2)) }

var centerX = { -var.B / var.D }
var centerY = { -var.C / var.D }

; Calculate the radius of the bore
var radius = { sqrt((var.centerX - var.x1) * (var.centerX - var.x1) + (var.centerY - var.y1) * (var.centerY - var.y1)) }

; Update global vars for correct workplace
set global.mosWPCtrPos[var.workOffset]   = { var.centerX, var.centerY }
set global.mosWPRad[var.workOffset]      = { var.radius }

; Move back to safe Z height
G6550 I{var.pID} Z{var.safeZ}

; Move to the calculated center of the bore
G6550 I{var.pID} X{var.centerX} Y{var.centerY}

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}

; Set WCS origin to the probed center
echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " X,Y origin to center of bore." }
G10 L2 P{var.wcsNumber} X{var.centerX} Y{var.centerY}
