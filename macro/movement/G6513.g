; G6513.g: SURFACE PROBE - MANUAL OR AUTOMATED - ONE OR MULTIPLE POINTS
;
; Replacement for G6512, thae uses the concept of surfaces rather than
; individual probe points. When given multiple points for a surface,
; these will be probed sequentially and if possible, further details
; and compensations will be applied based on the information we have.
;
; Example to probe 2 flat surfaces.
; Surface 1:
;   - Start at sx1, sy1, sz1
;   - Probe towards tx2, ty2, tz2
;   - Move to safe height S
;   - Start at sx2, sy2, sz2
;   - Probe towards tx2, ty2, tz2
;   - Move to safe height S
;   - Calculate surface angle and adjust probed position
; Surface 2:
;   - Start at sx3, sy3, sz3
;   - Probe towards tx4, ty4, tz4
;   - Move to safe height S
;   - Start at sx4, sy4, sz4
;   - Probe towards tx4, ty4, tz4
;   - Move to safe height S
;   - Calculate surface angle and adjust probed position

; Each pair of start and target positions is deemed to form a
; single surface.
; We currently only support probing flat surfaces, so this
; macro must be provided with an even number of start and target
; positions.

; A surface can be probed with a single point, or with more than
; 2 points

; G6513
;    I<optional-probe-id>
;    P{
;       { SURFACE 1
;           {
;               {sx1, sy1, sz1},
;               {tx1, ty1, tz1}
;           },
;           {
;               {sx2, sy2, sz2},
;               {tx2, ty2, tz2}
;           }
;       },
;       { SURFACE 2
;           {
;               {sx3, sy3, sz3},
;               {tx3, ty3, tz3}
;           },
;           {
;               {sx4, sy4, sz4},
;               {tx4, ty4, tz4}
;           }
;       },
;       ...
;    }
;    S<safe-z>                    - Safe Z position to return to between surfaces
;    D1                           - Do not move to safe height after each probe
;    H1                           - Do not move to safe height after each surface
;
; Remove I<N> from any calls to this macro to run the guided manual jogging process.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.I) && param.I != null && (sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8) }
    abort { "G6513: Invalid probe ID (I..), probe must be of type 5 or 8, or unset for manual probing." }

var probe               = { exists(param.I) ? param.I : null}
var manualProbe         = { var.probe == null }
var retractAfterPoint   = { !exists(param.D) || param.D != 1 }
var retractAfterSurface = { !exists(param.H) || param.H != 1 }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; Get current machine position
M5000 P0

; Note: We allow a safe-Z to be provided as a parameter, but default to
; the current Z position. The reason for this is that we cannot always
; assume that the current Z position is safe to move to the starting
; position at. This is particularly important when the PREVIOUS call to
; G6513 was made with a D1 parameter. This param means that the previous
; macro did not return to its' safe height after probing, and that means
; that _our_ safe height would be the current Z position, which is bad.

; So, we allow the safe-Z to be provided as a parameter in those cases
; where the user of this macro (other macros, mostly) know that we can
; make multiple probes at a particular height (e.g. one side-surface of
; a block), but we need to return to the safe height after the last
; probe to perform probing on the other surfaces.

var safeZ = { exists(param.S) ? param.S : global.mosMI[2] }

if { !exists(param.P) }
    abort { "G6513: Must provide a list of surfaces to probe (P..)!" }

if { state.currentTool >= #tools || state.currentTool < 0 }
    abort { "G6513: No tool selected! Select a tool before probing."}

; Create vector to store surfaces
var pSfc = { vector(#param.P, null) }

while { iterations < #param.P }
    var surfaceNo = { iterations }
    var curSurface = { param.P[var.surfaceNo] }

    ; Create vector to store probed points and surface angle
    set var.pSfc[var.surfaceNo] = { vector(#var.curSurface, {null, null, null}), 0}

    while { iterations < #var.curSurface }
        var pointNo = { iterations }
        var curPoint = { var.curSurface[var.pointNo] }

        echo { "Probing surface " ^ var.surfaceNo ^ "/" ^ #param.P ^ ", point " ^ var.pointNo ^ "/" ^ #var.curSurface }
        var startPos = { var.curPoint[0] }
        var targetPos = { var.curPoint[1] }

        ; Check if the positions are within machine limits
        M6515 X{ var.startPos[0] } Y{ var.startPos[1] } Z{ var.startPos[2] }
        M6515 X{ var.targetPos[0] } Y{ var.targetPos[1] } Z{ var.targetPos[2] }

        ; If starting probe height is above safe height,
        ; then move to the starting probe height first.
        if { var.startPos[2] > var.safeZ }
            G6550 I{ var.probe } Z{ var.startPos[2] }

        ; Move to starting position in X and Y
        G6550 I{ var.probe } X{ var.startPos[0] } Y{ var.startPos[1] }

        ; Move to probe height.
        ; No-op if we already moved above.
        G6550 I{ var.probe } Z{ var.startPos[2]}

        ; Run automated probing cycle
        if { var.manualProbe }
            G6512.2 X{ var.targetPos[0] } Y{ var.targetPos[1] } Z{ var.targetPos[2] }
        else
            ; Pass through E and R parameters if they exist
            G6512.1 I{ param.I } X{ var.targetPos[0] } Y{ var.targetPos[1] } Z{ var.targetPos[2] } R{ exists(param.R) ? param.R : null } E{ exists(param.E) ? param.E : 1 }

        ; Save probed point {X,Y,Z} into surface
        set var.pSfc[var.surfaceNo][0][var.pointNo] = { global.mosMI }

        ; Move back to starting position before moving to next probe point
        G6550 I{ param.I } X{ var.startPos[0] } Y{ var.startPos[1] }

        ; Move to safe height
        ; If probing move is called with D parameter,
        ; we stay at the same height.
        if { var.retractAfterPoint }
            G6550 I{ param.I } Z{ var.safeZ }

    if { var.retractAfterSurface }
        G6550 I{ param.I } Z{ var.safeZ }

    ; At this point we have probed all of the points of the surface.
    ; We now need to compensate for tool radius and deflection in X and Y.
    ; With 2 points on the surface, we assume this is a flat surface.
    ; With a flat surface, we can calculate the surface angle and
    ; its difference compared to a line perpendicular to the approach vector.
    ; We use this difference to modify the probe radius and deflection values before
    ; they are applied, to account for the fact that the probe may not contact
    ; the surface precisely along the approach vector.

    ; With 1 point, we cannot know anything about the surface.

    ; With 3 or more points, we assume that the surface is a curve and
    ; we treat this the same as a single point - apply compensation directly
    ; along the approach vector.

    var tRX = (global.mosTT[state.currentTool][0] - global.mosTT[state.currentTool][1][0])
    var tRY = (global.mosTT[state.currentTool][0] - global.mosTT[state.currentTool][1][1])

    var flatSurface = { #var.pPoint == 2 }

    var newPoint = { vector(#var.pPoint, null) }

    ; Calculate the angle of the approach vector for each point
    while { iterations < #var.pPoint }
        var curPoint = { var.pPoint[iterations] }

        ; Calculate the approach angle in radians
        var rApproach = { atan2(var.curPoint[1][0] - var.curPoint[0][0], var.curPoint[1][1] - var.curPoint[0][1]) }

        echo { "Probe approach angle: " ^ degrees(var.rApproach) }

        ; Apply full compensation amount along the approach vector on X and Y.
        var curX = { var.curPoint[0] + (cos(var.rApproach) * var.trX) }
        var curY = { var.curPoint[1] + (sin(var.rApproach) * var.trY) }

        ; Apply probe offsets if this is not a manual probe
        if { !var.manualProbe }
            set var.curX = { var.curX + sensors.probes[param.I].offsets[0] }
            set var.curY = { var.curY + sensors.probes[param.I].offsets[1] }

        ; Store compensated X and Y values with the uncompensated Z value
        set var.newPoint[iterations] = { var.curX, var.curY, var.curPoint[2] }

        echo { "Conventionally compensated point: X" ^ var.curX ^ " Y" ^ var.curY }

        ; If this is a flat surface and we're currently processing
        ; the second point, calculate the surface angle and adjust
        ; the new points.
        if { var.flatSurface && iterations == 1 }
            ; Calculate the surface angle from the raw points
            var rSurface = { atan2(var.pPoint[iterations][0] - var.pPoint[iterations-1][0], var.pPoint[iterations][1] - var.pPoint[iterations-1][1]) }

            ; Store it on the current surface
            set var.pSfc[var.surfaceNo][1] = { degrees(var.rSurface) }

            ; Calculate the difference between the approach and
            ; perpendicular angles
            var rDiff = { var.rApproach - (var.rSurface + pi/2) } ; This is in radians

            echo { "Surface angle: " ^ degrees(var.rSurface) ^ ", approach angle difference: " ^ degrees(var.rDiff) }

            ; Calculate the further compensation to apply based on the angle difference
            var dX = { ((sin(var.rDiff) * var.tRX)) }
            var dY = { ((cos(var.rDiff) * var.tRY)) }

            echo { "Further compensation required: X=" ^ var.dX ^ " Y=" ^ var.dY }

            ; Apply the compensation to the new points
            while { iterations < #var.newPoint }
                set var.newPoint[iterations][0] = { var.newPoint[iterations][0] + var.dX }
                set var.newPoint[iterations][1] = { var.newPoint[iterations][1] + var.dY }

        elif{ #var.pPoint == 1 }

            ; If we only probe 1 point, we assume the surface is flat
            ; and the surface angle is perpendicular to the approach vector.
            set var.pSfc[var.surfaceNo][1] = { degrees(var.rApproach + pi/2) }


        ; Otherwise we have more than 2 points. The surface is assumed to be a curve,
        ; probably a circle.


    ; Save the new point details
    set var.pSfc[var.surfaceNo] = { var.newPoint }

; Save the output surfaces
set global.mosMI = { var.pSfc }