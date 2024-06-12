; G6510.g: SINGLE SURFACE PROBE
;
; Meta macro to gather operator input before executing a
; single surface probe (G6512). The macro will explain to
; the operator what is about to happen and ask on which axis
; the user would like to run a probe cycle. The macro will ask
; the operator to jog to the starting location, then enter a
; depth to probe at (in the case of a Z probe, this is how deep
; we will attempt to probe from the starting location).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Friendly names to indicate the location of a surface to be probed, relative to the tool.
; Left means 'surface is to the left of the tool', i.e. we will move the table towards the
; _right_ to probe it.
; If your machine is configured with the axes in a different orientation, you can override
; these names in mos-user-vars.g but there is no way to override the "Below" option (which)
; is a Z axis, and always probes towards Z minimum. On the Milo, Z Max is 0 and Z min is 60 or 120.
var surfaceLocationNames = {"Left","Right","Front","Back","Top"}

; Index of the zProbe entry as this requires different inputs.
var zProbeI = { #var.surfaceLocationNames - 1 }

; Display description of surface probe if not displayed this session
if { global.mosTM && !global.mosDD[4] }
    M291 P"This operation finds the co-ordinate of a surface on a single axis. It is usually used to find the top surface of a workpiece but can be used to find X or Y positions as well." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: This operation will only return accurate results if the surface you are probing is perpendicular to the axis you are probing in." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"You will jog the tool or touch probe to your chosen starting position. Your starting position should be outside and above X or Y surfaces, or directly above the top surface." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: For X or Y surfaces, the probe will move down <b>BEFORE</b> moving horizontally to detect a surface. Bear this in mind when selecting a starting position." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"For X or Y surfaces, you will then be asked for a <b>probe depth</b>. This is how far your probe will move down from the starting position before moving in X or Y." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"Finally, you will be asked to set a <b>probe distance</b>. This is how far the probe will move towards a surface before returning an error if it did not trigger." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/single-surface"">View the Single Surface Documentation</a> for more details." R"MillenniumOS: Probe Surface" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Surface probe aborted!" }

    set global.mosDD[4] = true

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Prompt for overtravel distance
M291 P"Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surface to account for any innaccuracy in the dimensions." R"MillenniumOS: Probe Surface" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Single Surface probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0 }
    abort { "Overtravel distance must not be negative!" }

; Ask the operator to jog to their chosen starting position
M291 P"Please jog the probe or tool to your chosen starting position.<br/><b>CAUTION</b>: Remember - Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"MillenniumOS: Probe Surface" X1 Y1 Z1 T0 S3
if { result != 0 }
    abort { "Surface probe aborted!" }

; Prompt the operator for the location of the surface
M291 P"Please select the surface to probe.<br/><b>NOTE</b>: These surface names are relative to an operator standing at the front of the machine." R"MillenniumOS: Probe Surface" T0 S4 F{var.zProbeI} K{var.surfaceLocationNames}
var probeAxis = { input }

; For Z probes, our depth is 0 but our distance is the probing depth
var probeDepth = 0

var isZProbe = { var.probeAxis == var.zProbeI }

; If this is an X/Y probe, ask for depth
if { !var.isZProbe }
    M291 P"Please enter the depth to probe at in mm, below the current location.<br/><b>Example</b>: A value of 10 will move the probe downwards 10mm before probing outwards." R"MillenniumOS: Probe Surface" J1 T0 S6 F{global.mosOT}
    if { result != 0 }
        abort { "Surface probe aborted!" }

    set var.probeDepth = { input }

    if { var.probeDepth < 0 }
        abort { "Probing depth was negative!" }

M291 P"Please enter the distance to probe towards the surface in mm." R"MillenniumOS: Probe Surface" J1 T0 S6 F{global.mosCL}
if { result != 0 }
    abort { "Surface probe aborted!" }

var probeDist = { input }

if { var.probeDist < 0 }
    abort { "Probe distance was negative!" }

if { global.mosTM }
    if { !var.isZProbe }
        M291 P{"Probe will now move down <b>" ^ var.probeDepth ^ "</b> mm and probe towards the <b>" ^ var.surfaceLocationNames[var.probeAxis] ^ "</b> surface." } R"MillenniumOS: Probe Surface" T0 S4 K{"Continue", "Cancel"} F0
        if { input != 0 }
            abort { "Single Surface probe aborted!" }
    else
        M291 P{"Probe will now move towards the <b>" ^ var.surfaceLocationNames[var.probeAxis] ^ "</b> surface." } R"MillenniumOS: Probe Surface" T0 S4 K{"Continue", "Cancel"} F0
        if { input != 0 }
            abort { "Single Surface probe aborted!" }


G6510.1 W{exists(param.W)? param.W : null} H{var.probeAxis} I{var.probeDist} O{var.overtravel} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probeDepth}