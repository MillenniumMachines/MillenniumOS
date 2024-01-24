; G6508.1.g: OUTSIDE CORNER PROBE - EXECUTE
;
; Probe an outside corner of a workpiece, set target WCS X and Y
; co-ordinates to the probed corner, if requested.

if { !exists(param.H) || param.H < 0 || param.H > (#global.mosOriginCorners-1) }
    abort { "Must provide a valid corner index (H..)!" }

if { !exists(param.I) }
    abort { "Must provide distance inwards from corner to probe surfaces, in mm (I..)!" }

var maxWCS = #global.mosWorkOffsetCodes
if { exists(param.W) && (param.W < 1 || param.W > var.maxWCS) }
    abort { "WCS number (W..) must be between 1 and " ^ var.maxWCS ^ "!" }

if { exists(param.P) && param.P < 0 }
    abort { "X-axis secondary probe offset must be positive (P..)!" }

if { exists(param.Q) && param.Q < 0 }
    abort { "Y-axis secondary probe offset must be positive (Q..)!" }

; Check if either param.Q and param.P are set, but
; not both or neither, and abort if so.
if { exists(param.P) != exists(param.Q) }
    abort { "If providing secondary probe offsets (P.. and Q..), you must provide both!" }

if { !exists(param.J) || !exists(param.K) || !exists(param.L) }
    abort { "Must provide a start position to probe from using J, K and L parameters!" }

var hasSecondaries = { exists(param.P) && exists(param.Q) }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

var sX1 = null
var sY1 = null
var tX1 = null
var tY1 = null

var sX2 = null
var sY2 = null
var tX2 = null
var tY2 = null

; Calculate start and target positions based on corner index
if { param.H == 0 } or { param.H == 3 }
    set var.sX1 = { param.J }
    set var.sY1 = { param.K + param.I }
    set var.tX1 = { param.J + param.I }
else
    set var.sX1 = { param.J }
    set var.sY1 = { param.K - param.I }
    set var.tX1 = { param.J - param.I }
    set var.nX = -var.nX
endif

if { param.H == 0 } or { param.H == 1 }
    set var.sX2 = { param.J + param.I }
    set var.sY2 = { param.K }
    set var.tY2 = { param.K + param.I }
else
    set var.sX2 = { param.J - param.I }
    set var.sY2 = { param.K }
    set var.tY2 = { param.K - param.I }
    set var.nY = -var.nY
endif

var pR = { {0, 0}, {null, null}, {0, 0}, {null, null} }

set global.mosOutsideCornerNum = param.H

; Probe X surface
G6510.1 K{global.mosTouchProbeID} J{var.sX1} K{var.sY1} L{param.L} X{var.tX1}
set var.pR[0] = { global.mosProbeCoordinate[0], global.mosProbeCoordinate[1] }

; If we have a secondary probe offset on X, probe again
if { var.hasSecondaries }
    G6510.1 K{global.mosTouchProbeID} J{var.sX1} K{var.sY1 + param.P} L{param.L} X{var.tX1}
    set var.pR[1] = { global.mosProbeCoordinate[0], global.mosProbeCoordinate[1] }
endif

; Probe Y surface
G6510.1 K{global.mosTouchProbeID} J{var.sX2} K{var.sY2} L{param.L} Y{var.tY2}
set var.pR[2] = { global.mosProbeCoordinate[0], global.mosProbeCoordinate[1] }

; If we have a secondary probe offset on Y, probe again
if { var.hasSecondaries }
    G6510.1 K{global.mosTouchProbeID} J{var.sX2 + param.Q} K{var.sY2} L{param.L} Y{var.tY2}
    set var.pR[3] = { global.mosProbeCoordinate[0], global.mosProbeCoordinate[1] }
endif

; Set naiive corner position if we only have 1 probe
; point for each axis. We assume the surfaces probed are
; perpendicular to each axis and therefore the corner is
; where the X and Y co-ordinates cross.
if { !var.hasSecondaries }
    set global.mosOutsideCornerPos = { var.pR[0][0], var.pR[2][1] }
else
    ; Otherwise, we have multiple probe points on the same axes.
    ; Calculate an angle between the points for each axis, and then
    ; calculate where those lines across to identify the corner.
    var aX = { atan2(var.pR[1][1] - var.pR[0][1], var.pR[1][0] - var.pR[0][0]) }
    var aY = { atan2(var.pR[3][1] - var.pR[2][1], var.pR[3][0] - var.pR[2][0]) }

    var bX = { var.pR[0][1] - (var.pR[0][0] * tan(var.aX)) }
    var bY = { var.pR[2][1] - (var.pR[2][0] * tan(var.aY)) }

    var dX = { degrees(var.aX) }
    var dY = { degrees(var.aY) }

    ; This is the angle of each surface in relation to the X axis.
    ; The surface probed along the X axis SHOULD be at 90 degrees,
    ; and the surface probed along the Y axis SHOULD be at 0 degrees
    ; if the workpiece is perfectly square with the table (and the
    ; surface is completely flat).
    set global.mosOutsideCornerSurfaceAngle = { var.dX, var.dY }

    ; This is the angle of the corner itself, which should be 90 degrees
    ; if the workpiece is itself square.
    ; If the corner is square but the corner surface angles are not what
    ; we expect, then this indicates that the workpiece is not square with
    ; the table and we may be able to compensate for this using skew
    ; compensation. If the corner is not square, then we have no idea of
    ; the shape of the workpiece and we have to just let the user
    set global.mosOutsideCornerAngle = { abs(var.dX) + abs(var.dY) }
    set global.mosOutsideCornerPos = { (var.bY - var.bX) / (tan(var.aX) - tan(var.aY)), (tan(var.aX) * ((var.bY - var.bX) / (tan(var.aX) - tan(var.aY)))) + var.bX }

    ; If the corner is square, but one of the corner angles is not 90 degrees
    ; then the workpiece is not square with the table. We might be able to use
    ; skew compensation to correct for this.
    set global.mosOutsideCornerIsMisaligned = { global.mosOutsideCornerAngle == 90 && (var.dX != 90 || var.dY != 90) }

if { !global.mosExpertMode }
    echo { "Outside " ^ global.mosOriginCorners[param.H] ^ " corner is {" ^ global.mosOutsideCornerPos ^ "}" }

else
    echo { "global.mosOutsideCornerNum=" ^ global.mosOutsideCornerNum }
    echo { "global.mosOutsideCornerPos=" ^ global.mosOutsideCornerPos }

; Set WCS origin to the probed corner, if requested
if { exists(param.W) }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin." }
    G10 L2 P{param.W} X{global.mosProbeCoordinate[global.mosIX]} Y{global.mosProbeCoordinate[global.mosIY]}