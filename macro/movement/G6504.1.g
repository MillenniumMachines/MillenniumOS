; G6504.1.g: WEB - EXECUTE
;
; Probe the X or Y edges of a web (protruding feature). This works the same
; as a rectangle block probe, but only probes the X or Y edges of the feature.


; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

if { !exists(param.Z) }
    abort { "Must provide a probe position using the Z parameter!" }

if { !exists(param.N) || param.N < 0 || param.N > 1 }
    abort { "Must provide an axis to probe (N...), X=0, Y=1" }

if { !exists(param.H) }
    abort { "Must provide an approximate web width using the H parameter!" }

if { exists(param.T) && param.T != null && param.T <= 0 }
    abort { "Surface clearance distance must be greater than 0!" }

if { exists(param.O) && param.O != null && param.O <= 0 }
    abort { "Overtravel distance must be greater than 0!" }

; Probe mode defaults to (0=Full)
var pFull = { exists(param.Q) ? param.Q == 0: false }

if { var.pFull }
    if { !exists(param.I) }
        abort { "Must provide an approximate web length using the I parameter!" }

    if { exists(param.C) && param.C != null && param.C <= 0 }
        abort { "Edge clearance distance must be greater than 0!" }

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Increment the probe surface and point totals for status reporting
; If full mode is enabled, we probe at 2 points on each surface.
set global.mosPRST = { global.mosPRST + 2 }
set global.mosPRPT = { global.mosPRPT + (var.pFull ? 4 : 2) }

var pID = { global.mosFeatTouchProbe ? global.mosTPID : null }

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    abort { "Must run T" ^ global.mosPTID ^ " to select the probe tool before probing!" }

; Reset stored values that we're going to overwrite -
; center, dimensions and rotation
M5010 W{var.workOffset} R49

; Store our own safe Z position as the given L parameter.
var safeZ = { param.L }

; J = start position X
; K = start position Y
; L = start position Z
; Z = our probe height (absolute)
; H = approximate width of the web
; I = approximate length of the web (in full mode)

; Approximate center of web
var sX   = { param.J }
var sY   = { param.K }

; Web dimensions.
var fW   = { param.H }
var fL   = { (var.pFull) ? param.I : 0 }

; Half of the dimension of the web
var hW   = { var.fW/2 }
var hL   = { var.fL/2 }

; Tool Radius is the first entry for each value in
; our extended tool table.

; Apply tool radius to surface clearance. We want to
; make sure the surface of the tool and the workpiece
; are the clearance distance apart, rather than less
; than that.
var surfaceClearance = { ((!exists(param.T) || param.T == null) ? global.mosCL : param.T) + ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Default edge clearance to the normal clearance
; distance, but allow it to be overridden if necessary.
var edgeClearance = { var.pFull ? ((!exists(param.C) || param.C == null) ? ((!exists(param.T) || param.T == null) ? global.mosCL : param.T) : param.C): 0 }

; Apply tool radius to overtravel. We want to allow
; less movement past the expected point of contact
; with the surface based on the tool radius.
; For big tools and low overtravel values, this value
; might end up being negative. This is fine, as long
; as the configured tool radius is accurate.
var overtravel = { (exists(param.O) ? param.O : global.mosOT) - ((state.currentTool < #tools && state.currentTool >= 0) ? global.mosTT[state.currentTool][0] : 0) }

; Check that 2 times the clearance distance isn't
; higher than the length of the web.
if { var.pFull && var.edgeClearance >= var.hL }
    abort { "Edge clearance distance is more than half of the length of the web! Cannot probe." }

; The overtravel distance does not have the same
; requirement, as it is only used to adjust the
; probe target towards or away from the target
; surface rather.

; Calculate the probe positions for the surfaces
var points = { vector(2 - (var.pFull ? 0 : 1), {{null, null, param.Z}, {null, null, param.Z}}) }

var surface1 = { var.points }
var surface2 = { var.points }

; var.edgeClearance and var.hL will be zero if quick mode
; is enabled.

; Determine direction multipliers based on param.N
var dirX = { (param.N == 0) ? 1 : -1 }
var dirY = { (param.N == 0) ? -1 : 1 }

; Add initial probe points
if { param.N == 0 }
    ; sX = 266.393 sY = 77.755 hW = (76.2/2) hL = (50.8/2)
    ; N = 0
    set var.surface1[0][0][0] = { var.sX - var.dirX * (var.hW + var.surfaceClearance) }
    set var.surface1[0][1][0] = { var.sX - var.dirX * (var.hW - var.overtravel) }
    set var.surface1[0][0][1] = { var.sY + var.dirY * (var.hL - var.edgeClearance) }
    set var.surface1[0][1][1] = { var.sY + var.dirY * (var.hL - var.edgeClearance) }

    set var.surface2[0][0][0] = { var.sX + var.dirX * (var.hW + var.surfaceClearance) }
    set var.surface2[0][1][0] = { var.sX + var.dirX * (var.hW - var.overtravel) }
    set var.surface2[0][0][1] = { var.sY - var.dirY * (var.hL - var.edgeClearance) }
    set var.surface2[0][1][1] = { var.sY - var.dirY * (var.hL - var.edgeClearance) }
else
    set var.surface1[0][0][0] = { var.sX - var.dirX * (var.hL - var.edgeClearance) }
    set var.surface1[0][1][0] = { var.sX - var.dirX * (var.hL - var.edgeClearance) }
    set var.surface1[0][0][1] = { var.sY - var.dirY * (var.hW + var.surfaceClearance) }
    set var.surface1[0][1][1] = { var.sY - var.dirY * (var.hW - var.overtravel) }

    set var.surface2[0][0][0] = { var.sX + var.dirX * (var.hL - var.edgeClearance) }
    set var.surface2[0][1][0] = { var.sX + var.dirX * (var.hL - var.edgeClearance) }
    set var.surface2[0][0][1] = { var.sY + var.dirY * (var.hW + var.surfaceClearance) }
    set var.surface2[0][1][1] = { var.sY + var.dirY * (var.hW - var.overtravel) }

; Add secondary probe points if full mode is enabled
if { var.pFull }
    if { param.N == 0 }
        set var.surface1[1][0][0] = { var.surface1[0][0][0] }
        set var.surface1[1][1][0] = { var.surface1[0][1][0] }
        set var.surface1[1][0][1] = { var.sY - var.dirY * (var.hL - var.edgeClearance) }
        set var.surface1[1][1][1] = { var.sY - var.dirY * (var.hL - var.edgeClearance) }

        set var.surface2[1][0][0] = { var.surface2[0][0][0] }
        set var.surface2[1][1][0] = { var.surface2[0][1][0] }
        set var.surface2[1][0][1] = { var.sY + var.dirY * (var.hL - var.edgeClearance) }
        set var.surface2[1][1][1] = { var.sY + var.dirY * (var.hL - var.edgeClearance) }
    else
        set var.surface1[1][0][0] = { var.sX + var.dirX * (var.hL - var.edgeClearance) }
        set var.surface1[1][1][0] = { var.sX + var.dirX * (var.hL - var.edgeClearance) }
        set var.surface1[1][0][1] = { var.surface1[0][0][1] }
        set var.surface1[1][1][1] = { var.surface1[0][1][1] }

        set var.surface2[1][0][0] = { var.sX - var.dirX * (var.hL - var.edgeClearance) }
        set var.surface2[1][1][0] = { var.sX - var.dirX * (var.hL - var.edgeClearance) }
        set var.surface2[1][0][1] = { var.surface2[0][0][1] }
        set var.surface2[1][1][1] = { var.surface2[0][1][1] }

; Probe the 2 surfaces
; Retract between each surface but
; not between each point
G6513 I{var.pID} D1 H0 P{var.surface1, var.surface2} S{var.safeZ}

var pSfc = { global.mosMI }

; If running in quick mode, the web center is the midpoint
; of the 2 points we probed.
if { !var.pFull }
    ; Set the midpoint on the relevant axis
    set global.mosWPCtrPos[var.workOffset][param.N] = { (var.pSfc[0][0][0][param.N] + var.pSfc[1][0][0][param.N]) / 2 }

    ; Calculate the actual probed dimension of the web
    set global.mosWPDims[var.workOffset][param.N] = { abs(var.pSfc[0][0][0][param.N] - var.pSfc[1][0][0][param.N]) }

else
    ; Angle difference in radians
    var rAngleDiff = { abs(mod(var.pSfc[0][2] - var.pSfc[1][2], pi)) }

    ; Normalise the angle difference to be between 0 and 90 degrees
    if { var.rAngleDiff > pi/2 }
        set var.rAngleDiff = { pi - var.rAngleDiff }

    ; Make sure surfaces are suitably parallel
    if { degrees(var.rAngleDiff) > global.mosAngleTol }
        abort { "Web surfaces are not parallel (" ^ degrees(var.rAngleDiff) ^ " > " ^ global.mosAngleTol ^ ") - this web does not appear to be parallel." }

    set global.mosWPCtrPos[var.workOffset][param.N] = { (var.pSfc[0][0][0][param.N] + var.pSfc[0][0][1][param.N] + var.pSfc[1][0][0][param.N] + var.pSfc[1][0][1][param.N]) / 4 }


    ; We can now calculate the dimensions of the web
    ; The dimensions are the difference between the average of each
    ; pair of points of each line.
    set global.mosWPDims[var.workOffset][param.N] = { abs((var.pSfc[0][0][0][param.N] + var.pSfc[0][0][1][param.N]) / 2 - (var.pSfc[1][0][0][param.N] + var.pSfc[1][0][1][param.N]) / 2) }

    ; Calculate the rotation of the web.
    ; After the checks above, we know the web has parallel
    ; surfaces, so we can assume that the angle of the first
    ; surface is the angle of the web.
    ; We need to normalise this to between 0 and 45 degrees.
    var aR = { (param.N == 0) ? var.pSfc[0][2] - (pi/2) : var.pSfc[0][2] }

    ; Reduce the angle to below +/- 45 degrees (pi/4 radians)
    while { var.aR > pi/4 || var.aR < -pi/4 }
        if { var.aR > pi/4 }
            set var.aR = { var.aR - pi/2 }
        elif { var.aR < -pi/4 }
            set var.aR = { var.aR + pi/2 }

    set global.mosWPDeg[var.workOffset] = { degrees(var.aR) }

; Make sure we're at the safeZ height
G6550 I{var.pID} Z{var.safeZ}

; Move to the calculated center of the web, at the original
; start position in the other axis.
var cX = { (param.N == 0) ? global.mosWPCtrPos[var.workOffset][0] : var.sX }
var cY = { (param.N == 1) ? global.mosWPCtrPos[var.workOffset][1] : var.sY }

G6550 I{var.pID} X{(param.N == 0) ? var.cX : var.sX} Y{(param.N == 1) ? var.cY : var.sY}

; Report probe results if requested
if { !exists(param.R) || param.R != 0 }
    M7601 W{var.workOffset}
    echo { "MillenniumOS: Setting WCS " ^ var.wcsNumber ^ " " ^ (param.N == 0 ? "X" : "Y") ^ " origin to web center." }

; Set WCS origin to the probed center
if { param.N == 0 }
    G10 L2 P{var.wcsNumber} X{ var.cX }
elif { param.N == 1 }
    G10 L2 P{var.wcsNumber} Y{ var.cY }
