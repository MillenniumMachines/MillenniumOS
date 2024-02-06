; G6510.g: SINGLE SURFACE PROBE
;
; Meta macro to gather operator input before executing a
; single surface probe (G6512). The macro will explain to
; the operator what is about to happen and ask on which axis
; the user would like to run a probe cycle. The macro will ask
; the operator to jog to the starting location, then enter a
; depth to probe at (in the case of a Z probe, this is how deep
; we will attempt to probe from the starting location).

var zProbeI = { #global.mosSurfaceLocationNames - 1 }
var probeId = { global.mosFeatureTouchProbe ? global.mosTouchProbeID : null }

; Display description of surface probe if not displayed this session
if { !global.mosExpertMode && !global.mosDescDisplayed[4] }
    M291 P"This operation finds the co-ordinate of a surface on a single axis. It is usually used to find the top surface of a workpiece but can be used to find X or Y positions as well." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: This operation will only return accurate results if the surface you are probing is perpendicular to the axis you are probing in." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"You will jog the tool or touch probe to your chosen starting position. Your starting position should be outside and above X or Y surfaces, or directly above the top surface." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: For X or Y surfaces, the probe will move down <b>BEFORE</b> moving horizontally to detect a surface. Bear this in mind when selecting a starting position." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"For X or Y surfaces, you will then be asked for a <b>probe depth</b>. This is how far your probe will move down from the starting position before moving in X or Y." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"Finally, you will be asked to set a <b>probe distance</b>. This is how far the probe will move towards a surface before returning an error if it did not trigger." R"MillenniumOS: Probe Surface" T0 S3
    if { result != 0 }
        abort { "Surface probe aborted!" }

    set global.mosDescDisplayed[4] = true

; Ask the operator to jog to their chosen starting position
M291 P"Please jog the probe or tool to your chosen starting position.<br/><b>CAUTION</b>: Remember - Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"MillenniumOS: Probe Surface" X1 Y1 Z1 T0 S3
if { result != 0 }
    abort { "Surface probe aborted!" }

; Prompt the operator for the location of the surface
M291 P"Select the location of the surface to be probed in relation to the tool." R"MillenniumOS: Probe Surface" T0 S4 F{var.zProbeI} K{global.mosSurfaceLocationNames}
var probeAxis = { input }

var probingDepth = 0

var isZProbe = { var.probeAxis == var.zProbeI }

; If this is an X/Y probe, ask for depth
if { !var.isZProbe }
    M291 P"Please enter the depth to probe at in mm, below the current location.<br/><b>Example</b>: A value of 10 will move the probe downwards 10mm before probing outwards." R"MillenniumOS: Probe Surface" J1 T0 S6 F{global.mosProbeOvertravel}
    if { result != 0 }
        abort { "Surface probe aborted!" }
    else
        set var.probingDepth = { input }

        if { var.probingDepth < 0 }
            abort { "Probing depth was negative!" }

M291 P"Please enter the distance to probe towards the surface in mm." R"MillenniumOS: Probe Surface" J1 T0 S6 F{global.mosProbeOvertravel}
if { result != 0 }
    abort { "Surface probe aborted!" }

var probingDist = { input }

if { var.probingDist < 0 }
    abort { "Probing distance was negative!" }

; Set target positions
var tPX = { move.axes[0].machinePosition }
var tPY = { move.axes[1].machinePosition }
var tPZ = { move.axes[2].machinePosition }

; X and Y probes default to current position as
; start position, but we need to supply a Z
; co-ordinate for safety purposes.
var sZ = { var.tPZ }

; If this is an X/Y probe, we need to move down
; to our starting position and probe horizontally.
; Our target Z position should not change.
if { !var.isZProbe }
    set var.sZ = { var.sZ - var.probingDepth }
    set var.tPZ = { var.sZ }

if { var.probeAxis == 0 }
    set var.tPX = { var.tPX - var.probingDist }
elif { var.probeAxis == 1 }
    set var.tPX = { var.tPX + var.probingDist }
elif { var.probeAxis == 2 }
    set var.tPY = { var.tPY - var.probingDist }
elif { var.probeAxis == 3 }
    set var.tPY = { var.tPY + var.probingDist }
elif { var.probeAxis == 4 }
    set var.tPZ = { var.tPZ - var.probingDist }

; Check if the positions are within machine limits
G6515 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

if { !global.mosExpertMode }
    if { !var.isZProbe }
        M291 P{"We will now move downwards " ^ var.probingDepth ^ "mm and begin probing towards X=" ^ var.tPX ^ " Y=" ^ var.tPY } R"MillenniumOS: Probe Surface" T0 S3
    else
        M291 P{"We will now begin probing downwards towards Z=" ^ var.tPZ} R"MillenniumOS: Probe Surface" T0 S3
    if { result != 0 }
        abort { "Surface probe aborted!" }

; Run probing operation
G6512 I{var.probeId} L{var.sZ} X{var.tPX} Y{var.tPY} Z{var.tPZ}

var sAxis = { (var.probeAxis <= 1)? "X" : (var.probeAxis <= 3)? "Y" : "Z" }

; Set the axis that we probed on
set global.mosWorkPieceSurfaceAxis = { var.sAxis }

; Set surface position on relevant axis
set global.mosWorkPieceSurfacePos = { (var.probeAxis <= 1)? global.mosProbeCoordinate[0] : (var.probeAxis <= 3)? global.mosProbeCoordinate[1] : global.mosProbeCoordinate[2] }

if { !global.mosExpertMode }
    echo { "MillenniumOS: Surface - " ^ var.sAxis ^ "=" ^ global.mosWorkPieceSurfacePos }
else
    echo { "global.mosWorkPieceSurfaceAxis=" ^ global.mosWorkPieceSurfaceAxis }
    echo { "global.mosWorkPieceSurfacePos=" ^ global.mosWorkPieceSurfacePos }

; Set WCS if required
if { exists(param.W) && param.W != null }
    echo { "Setting WCS " ^ param.W ^ " " ^ var.sAxis ^ " origin to probed co-ordinate" }
    if { var.probeAxis <= 1 }
        G10 L2 P{param.W} X{global.mosWorkPieceSurfacePos}
    elif { var.probeAxis <= 3 }
        G10 L2 P{param.W} Y{global.mosWorkPieceSurfacePos}
    else
        G10 L2 P{param.W} Z{global.mosWorkPieceSurfacePos}


; Save code of last probe cycle
set global.mosLastProbeCycle = "G6510"
