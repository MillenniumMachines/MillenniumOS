; G6520.g: PROBE WORK PIECE - VISE CORNER
;
; Meta macro to gather operator input before executing a
; top surface probe and then an outside corner probe to
; zero all co-ordinates at once.
; The macro will explain to the operator what is about to
; happen and ask them to jog over the corner in question.
; The macro will then ask the operator for a clearance and
; overtravel distance, and where the corner is in relation
; to the current position of the probe. The operator will
; then be asked for approximate width (X axis) and length
; (Y axis) of the surfaces that form the corner in question.
; We try to load these values automatically from the last
; workpiece probe so if a workpiece has already been
; measured using a different macro then we can pre-populate
; the values.
; We will then run the underlying G6520.1 and macro to execute
; the probe cycle.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Make sure we're in the default motion system
M598

; Display description of vise corner probe if not already displayed this session
if { global.mosTutorialMode && !global.mosDescDisplayed[11] }
    M291 P"This probe cycle finds the X, Y and Z co-ordinates of the corner of a workpiece by probing the top surface and twice each along the 2 edges that form the corner." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"You will be asked to enter approximate <b>surface lengths</b> for the surfaces forming the corner, a <b>clearance distance</b> and an <b>overtravel distance</b>." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"These define how far the probe will move along the surfaces from the corner location before probing, and how far inwards from the expected surface the probe can move before erroring if not triggered." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"You will then jog the tool over the corner to be probed.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Vise Corner" T0 S3
    if { result != 0 }
        abort { "Vise corner probe aborted!" }
    set global.mosDescDisplayed[11] = true

; Make sure probe tool is selected
if { global.mosProbeToolID != state.currentTool }
    T T{global.mosProbeToolID}

var tR = { global.mosToolTable[state.currentTool][0]}

var sW = { (global.mosWorkPieceDimensions[0] != null) ? global.mosWorkPieceDimensions[0] : 100 }
M291 P{"Please enter approximate <b>surface length</b> along the X axis in mm.<br/><b>NOTE</b>: Along the X axis means the surface facing towards or directly away from the operator."} R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{var.sW}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var xSurfaceLength = { input }

if { var.xSurfaceLength < var.tR }
    abort { "X surface length too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

var sL = { (global.mosWorkPieceDimensions[1] != null) ? global.mosWorkPieceDimensions[1] : 100 }
M291 P{"Please enter approximate <b>surface length</b> along the Y axis in mm.<br/><b>NOTE</b>: Along the Y axis means the surface to the left or the right of the operator."} R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{var.sL}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var ySurfaceLength = { input }

if { var.ySurfaceLength < var.tR }
    abort { "Y surface length too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

; Prompt for clearance distance
M291 P"Please enter <b>clearance</b> distance in mm.<br/>This is how far far out we move from the expected surface to account for any innaccuracy in the corner location." R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{global.mosProbeClearance}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var clearance = { input }
if { var.clearance < var.tR }
    abort { Clearance distance too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

; Prompt for overtravel distance
M291 P"Please enter <b>overtravel</b> distance in mm.<br/>This is how far far in we move from the expected surface to account for any innaccuracy in the dimensions." R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{global.mosProbeOvertravel}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0 }
    abort { "Overtravel distance must not be negative!" }

M291 P"Please jog the probe <b>OVER</b> the corner and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" R"MillenniumOS: Probe Vise Corner" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Vise corner probe aborted!" }

M291 P"Please select the corner to probe.<br/><b>NOTE</b>: These surface names are relative to an operator standing at the front of the machine." R"MillenniumOS: Probe Vise Corner" T0 S4 K{global.mosOutsideCornerNames}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var corner = { input }

M291 P"Please enter the depth to probe at in mm, relative to the top surface of the workpiece. A value of 10 will move the probe downwards 10mm before probing inwards." R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{global.mosProbeOvertravel}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var probeDepth = { input }

if { var.probeDepth < 0 }
    abort { "Probing depth must not be negative!" }

; Run the block probe cycle
if { global.mosTutorialMode }
    var cN = { global.mosOutsideCornerNames[var.corner] }
    M291 P{"We will now probe the top surface, then move outside the <b>" ^ var.cN ^ "</b> corner and down " ^ var.probeDepth ^ "mm, then probe 2 points " ^ var.clearance ^ "mm from each end of the corner surfaces." } R"MillenniumOS: Probe Vise Corner" T0 S3
    if { result != 0 }
        abort { "Vise corner probe aborted!" }

G6520.1 W{exists(param.W)? param.W : null} H{var.xSurfaceLength} I{var.ySurfaceLength} N{var.corner} T{var.clearance} O{var.overtravel} P{var.probeDepth} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition}
