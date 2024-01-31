; G6510.g: SINGLE SURFACE PROBE
;
; Meta macro to gather operator input before executing a
; single surface probe (G6512). The macro will explain to
; the operator what is about to happen and ask on which axis
; the user would like to run a probe cycle. The macro will ask
; the operator to jog to the starting location, then enter a
; depth to probe at (in the case of a Z probe, this is how deep
; we will attempt to probe from the starting location).

var axisNames = { "X+", "X-", "Y+", "Y-", "Z-" }
var zProbeI = { #var.axisNames - 1 }

; Display description of surface probe if not displayed this session
if { !global.mosExpertMode && !global.mosDescSurfaceDisplayed }
    M291 P"This operation finds the co-ordinate of a surface on a single axis. It is usually used to find the Z height of a workpiece but can be used to find X or Y positions as well." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: This operation will only return accurate results if the surface you are probing is perpendicular to the axis you are probing in." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"You will be asked to select an <b>axis</b> (to probe <i>along</i>) and a <b>direction</b> (to probe <i>towards</i>)." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"You will then jog the touch probe to your chosen starting position.<br/><b>CAUTION</b>: Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"MillenniumOS: Probe Surface" T0 S2
    M291 P"If you are probing on the X or Y axes, you will then be asked for a <b>probe depth</b>. This is how far your probe will move down from the starting position before moving in X or Y." R"MillenniumOS: Probe Surface" T0 S3
    if { result != 0 }
        abort { "Surface probe aborted!" }
        M99
    set global.mosDescSurfaceDisplayed = true

; Prompt for probe axis and direction
; TODO: Picture of relevant probe movements
M291 P"Select a probing axis and direction:" R"MillenniumOS: Probe Surface" T0 S4 F{var.zProbeI} K{var.axisNames}
var probeAxis = { input }

M291 P"Now jog the probe tip near, but above the surface to be probed." R"MillenniumOS: Probe Surface" X1 Y1 Z1 T0 S3
if { result != 0 }
    abort { "Surface probe aborted!" }
else
    var probingDepth = 0

    ; If this is an X/Y probe, ask for depth
    if { var.probeAxis < var.zProbeI }
        M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing outwards." R"MillenniumOS: Probe Surface" J1 T0 S6 F{global.mosProbeOvertravel}
        if { result != 0 }
            abort { "Surface probe aborted!" }
            M99
        else
            set var.probingDepth = { input }

            if { var.probingDepth < 0}
                abort { "Probing depth was negative!" }
                M99

            if { !global.mosExpertMode }
                M291 P{"Probe will now move downwards " ^ var.probingDepth ^ "mm and probe towards " ^ var.axisNames[var.probeAxis]} R"MillenniumOS: Probe Surface" T0 S3
                if { result != 0 }
                    abort { "Surface probe aborted!" }
                    M99

        ; Set starting positions
        var tpX = move.axes[global.mosIX].machinePosition
        var tpY = move.axes[global.mosIX].machinePosition

        if { var.probeAxis == 0 }
            set var.tpX = { move.axes[global.mosIX].max }
        elif { var.probeAxis == 1 }
            set var.tpX = { move.axes[global.mosIX].min }
        elif { var.probeAxis == 2 }
            set var.tpY = { move.axes[global.mosIY].max }
        elif { var.probeAxis == 3 }
            set var.tpY = { move.axes[global.mosIY].min }

        G6512 I{global.mosTouchProbeID} L{move.axes[global.mosIZ].machinePosition - var.probingDepth} X{var.tpX} Y{var.tpY}

    else
        ; Run the surface probe cycle
        if { !global.mosExpertMode }
            M291 P{"We will now probe downwards towards " ^ var.axisNames[var.probeAxis]} R"MillenniumOS: Probe Surface" T0 S3
            if { result != 0 }
                abort { "Surface probe aborted!" }
                M99

            G6512 I{global.mosTouchProbeID} L{move.axes[global.mosIZ].machinePosition} Z{move.axes[global.mosIZ].min}


    var pX = { global.mosProbeCoordinate[global.mosIX] }
    var pY = { global.mosProbeCoordinate[global.mosIY] }
    var pZ = { global.mosProbeCoordinate[global.mosIZ] }

    ; Set the axis that we probed on
    set global.mosSurfaceAxis = { var.axisNames[var.probeAxis] }

    var setWCS = { exists(param.W) && param.W != null }

    var sAxis = { (var.probeAxis <= 1)? "X" : (var.probeAxis <= 3)? "Y" : "Z" }

    ; Set surface position on relevant axis
    set global.mosSurfacePos = { (var.probeAxis <= 1)? var.pX : (var.probeAxis <= 3)? var.pY : var.pZ }

    if { !global.mosExpertMode }
        echo { "MillenniumOS: Surface - " ^ var.sAxis ^ "=" ^ global.mosSurfacePos }
    else
        echo { "global.mosSurfaceAxis=" ^ global.mosSurfaceAxis }
        echo { "global.mosSurfacePos=" ^ global.mosSurfacePos }

    ; Set WCS if required
    if { var.setWCS }
        echo { "Setting WCS " ^ param.W ^ " " ^ var.sAxis ^ " origin to probed co-ordinate" }
        if { var.probeAxis <= 1 }
            G10 L2 P{param.W} X{global.mosSurfacePos}
        elif { var.probeAxis <= 3 }
            G10 L2 P{param.W} Y{global.mosSurfacePos}
        else
            G10 L2 P{param.W} Z{global.mosSurfacePos}


    ; Save code of last probe cycle
    set global.mosLastProbeCycle = "G6510"
