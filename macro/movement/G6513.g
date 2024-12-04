; G6513.g: SURFACE PROBE - MANUAL OR AUTOMATED - MULTIPLE POINTS
;
; Using the underlying G6512.1 and G6512.2, this uses the concept
; of surfaces rather than individual probe points. A surface consists
; of two points, each point having a start and target position.
; These will be probed sequentially and if possible, further details
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

if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    abort { "All axes must be homed before probing!" }

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

if { #param.P < 1 }
    abort { "G6513: Must provide at least one surface to probe!" }

if { state.currentTool >= #tools || state.currentTool < 0 }
    abort { "G6513: No tool selected! Select a tool before probing."}

; Create vector to store surfaces
var pSfc = { vector(#param.P, null) }

var trX = { global.mosTT[state.currentTool][0] - global.mosTT[state.currentTool][1][0] }
var trY = { global.mosTT[state.currentTool][0] - global.mosTT[state.currentTool][1][1] }

; Iterate over surfaces and run probes
; Track total number of points probed to calculate progress
while { iterations < #param.P }
    var surfaceNo = { iterations }
    var curSurface = { param.P[var.surfaceNo] }

    ; Create vector to store start points, probed points, approach angle and surface angle
    set var.pSfc[var.surfaceNo] = { vector(#var.curSurface, {{null, null, null}, {null, null, null}}), 0, null}

    var lastPos = { null }

    if { #var.curSurface > 2 }
        abort { "G6513: A maximum of 2 points per surface are supported!" }

    ; Iterate over probe points
    while { iterations < #var.curSurface }
        var pointNo = { iterations }
        var startPos = { var.curSurface[var.pointNo][0] }
        var targetPos = { var.curSurface[var.pointNo][1] }

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

        ; Retrieve the probed point
        var probedPos = { global.mosMI }

        ; Calculate the approach angle in radians based on the start and probed position
        var rApproachCur = { atan2(var.probedPos[0] - var.startPos[0], var.probedPos[1] - var.startPos[1]) }

        ; Accumulate the approach angle
        set var.pSfc[var.surfaceNo][1] = { var.pSfc[var.surfaceNo][1] + (var.rApproachCur / #var.curSurface) }

        ; Store the probed position
        set var.pSfc[var.surfaceNo][0][var.pointNo] = { var.probedPos }

        ; Set our surface angle perpendicular to the approach angle
        ; if we don't have a previous surface angle
        if { var.pSfc[var.surfaceNo][2] == null }
            set var.pSfc[var.surfaceNo][2] = { var.pSfc[var.surfaceNo][1] + pi/2 }

        ; Calculate a surface angle from the probe point once we have two points
        if { var.lastPos != null }
            ; Calculate the surface angle from the raw points
            set var.pSfc[var.surfaceNo][2] = { atan2(var.probedPos[0] - var.lastPos[0], var.probedPos[1] - var.lastPos[1]) }

        ; Move back to starting position before moving to next probe point
        G6550 I{ param.I } X{ var.startPos[0] } Y{ var.startPos[1] }

        ; Move to safe height
        ; If probing move is called with D parameter,
        ; we stay at the same height.
        if { var.retractAfterPoint }
            G6550 I{ param.I } Z{ var.safeZ }

        set var.lastPos = { var.probedPos }

        ; Update the number of points probed
        set global.mosPRPS = { global.mosPRPS + 1 }

    if { var.retractAfterSurface }
        G6550 I{ param.I } Z{ var.safeZ }

    ; Update the number of surfaces probed
    set global.mosPRSS = { global.mosPRSS + 1 }

; Okay, now we've probed all points and performed precalculations.
; We use the calculated approach and surface angles to adjust the
; probed points based on the tool radius and deflection.

; Iterate over all the probed surfaces
while { iterations < #var.pSfc }
    var surfaceNo = { iterations }
    var surfacePoints = { var.pSfc[iterations][0] }

    var rApproach = { var.pSfc[iterations][1] }
    var rSurface = { var.pSfc[iterations][2] }

    var dX = 0
    var dY = 0

    ; Calculate the difference between the approach and perpendicular-to-surface angles.
    ; Adjust rActual to be in the same direction as rApproach
    var rActual = { (var.rSurface + pi/2) }

    if { (var.rApproach - var.rActual) < -pi/2 }
        set var.rActual = { var.rActual + pi }
    elif { (var.rApproach - var.rActual) > pi/2 }
        set var.rActual = { var.rActual - pi }

    var rDiff = { var.rApproach - var.rActual }

    ; echo { "Surface #" ^ (iterations+1) ^ " surface angle: " ^ degrees(var.rSurface) ^ ", approach angle: " ^ degrees(var.rApproach) ^ " difference: " ^ degrees(var.rDiff) }

    ; Calculate the compensation to apply
    var dcosX = { var.trX * cos(var.rDiff) }
    var dsinX = { var.trX * sin(var.rDiff) }
    var dcosY = { var.trY * cos(var.rDiff) }
    var dsinY = { var.trY * sin(var.rDiff) }

    ; Select cos or sin compensation based on 45-degree quadrants
    if { var.rApproach > -3*pi/4 && var.rApproach < -pi/4 }
        ; Right surface
        set var.dX = { -abs(var.dcosX) }
        set var.dY = { var.rSurface > 0 ? abs(var.dsinY) : -abs(var.dsinY) }
    elif { var.rApproach > pi/4 && var.rApproach < 3*pi/4 }
        ; Left surface
        set var.dX = { abs(var.dcosX) }
        set var.dY = { var.rSurface > 0 ? abs(var.dsinY) : -abs(var.dsinY) }
    elif { var.rApproach > -pi/4 && var.rApproach < pi/4 }
        ; Front surface
        set var.dX = { var.rSurface > 0 ? -abs(var.dsinX) : abs(var.dsinX) }
        set var.dY = { abs(var.dcosY) }
    elif { (var.rApproach > 3*pi/4 && var.rApproach < pi) || (var.rApproach > -pi && var.rApproach < -3*pi/4) }
        ; Back surface
        set var.dX = { var.rSurface > 0 ? abs(var.dsinX) : -abs(var.dsinX) }
        set var.dY = { -abs(var.dcosY) }

    ; echo { "Compensation: " ^ var.dX ^ ", " ^ var.dY }

    ; Adjust each of the points
    while { iterations < #var.surfacePoints }
        ; Do not overwrite the original vector otherwise
        ; we will lose the Z value in index 2
        set var.pSfc[var.surfaceNo][0][iterations][0] = { var.surfacePoints[iterations][0] + var.dX }
        set var.pSfc[var.surfaceNo][0][iterations][1] = { var.surfacePoints[iterations][1] + var.dY }

    ; Save the output surfaces
    set global.mosMI = { var.pSfc }