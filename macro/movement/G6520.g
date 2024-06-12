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

; Display description of vise corner probe if not already displayed this session
if { global.mosTM && !global.mosDD[11] }
    M291 P"This probe cycle finds the X, Y and Z co-ordinates of the corner of a workpiece by probing the top surface and each of the edges that form the corner." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"In <b>Full</b> mode, this cycle will take 2 probe points on each edge, allowing us to calculate the position and angle of the corner and the rotation of the workpiece." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"You will be asked to enter an approximate <b>surface length</b> for the surfaces forming the corner, to calculate the 4 probe locations." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"In <b>Quick</b> mode, this cycle will take 1 probe point on each edge, assuming the corner is square and the workpiece is aligned with the table, and will return the extrapolated position of the corner." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"For both modes, you will be asked to enter a <b>clearance distance</b> and an <b>overtravel distance</b>." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"These define how far the probe will move along the surfaces from the corner location before probing, and how far past the expected surface the probe can move before erroring if not triggered." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"You will then jog the tool over the corner to be probed.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status - <b>Be Careful!</b>" R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"Finally, you will be asked to select the corner that is being probed, and the depth below the top surface to probe the corner surfaces at, in mm." R"MillenniumOS: Probe Vise Corner" S2
    M291 P"If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/vise-corner"">View the Vise Corner Documentation</a> for more details." R"MillenniumOS: Probe Vise Corner" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Vise corner probe aborted!" }
    set global.mosDD[11] = true

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

var tR = { global.mosTT[state.currentTool][0]}

M291 P{"Please select the probing mode to use.<br/><b>Full</b> will probe 2 points on each horizontal surface, while <b>Quick</b> will probe only 1 point."} R"MillenniumOS: Probe Outside Corner" T0 S4 K{"Full","Quick"} F0
if { result != 0 }
    abort { "Outside corner probe aborted!" }

var mode = { input }

var xSL  = null
var ySL  = null

; 0 = Full mode, 1 = Quick mode
if { var.mode == 0 }

    var sW = { (global.mosWPDims[0] != null) ? global.mosWPDims[0] : 100 }
    M291 P{"Please enter approximate <b>surface length</b> along the X axis in mm.<br/><b>NOTE</b>: Along the X axis means the surface facing towards or directly away from the operator."} R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{var.sW}
    if { result != 0 }
        abort { "Vise corner probe aborted!" }

    set var.xSL = { input }

    if { var.xSL < var.tR }
        abort { "X surface length too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

    var sL = { (global.mosWPDims[1] != null) ? global.mosWPDims[1] : 100 }
    M291 P{"Please enter approximate <b>surface length</b> along the Y axis in mm.<br/><b>NOTE</b>: Along the Y axis means the surface to the left or the right of the operator."} R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{var.sL}
    if { result != 0 }
        abort { "Vise corner probe aborted!" }

    set var.ySL = { input }

    if { var.ySL < var.tR }
        abort { "Y surface length too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

; Prompt for clearance distance
M291 P"Please enter <b>clearance</b> distance in mm.<br/>This is how far away from the expected surface we start probing from, to account for any innaccuracy in the corner location." R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{global.mosCL}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var clearance = { input }
if { var.clearance < var.tR }
    abort { Clearance distance too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

; Prompt for overtravel distance
M291 P"Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surface to account for any innaccuracy in the dimensions." R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0 }
    abort { "Overtravel distance must not be negative!" }

M291 P"Please jog the probe <b>OVER</b> the corner and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" R"MillenniumOS: Probe Vise Corner" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Vise corner probe aborted!" }

M291 P"Please select the corner to probe.<br/><b>NOTE</b>: These surface names are relative to an operator standing at the front of the machine." R"MillenniumOS: Probe Vise Corner" T0 S4 K{global.mosCnr}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var corner = { input }

M291 P"Please enter the depth to probe at in mm, relative to the top surface of the workpiece. A value of 10 will move the probe downwards 10mm before probing inwards." R"MillenniumOS: Probe Vise Corner" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Vise corner probe aborted!" }

var probeDepth = { input }

if { var.probeDepth < 0 }
    abort { "Probing depth must not be negative!" }

; Run the block probe cycle
if { global.mosTM }
    var cN = { global.mosCnr[var.corner] }
    M291 P{"We will now probe the top surface, then move outside the <b>" ^ var.cN ^ "</b> corner, down " ^ var.probeDepth ^ "mm, and probe each surface forming the corner." } R"MillenniumOS: Probe Vise Corner" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Vise corner probe aborted!" }

G6520.1 W{exists(param.W)? param.W : null} Q{var.mode} H{var.xSL} I{var.ySL} N{var.corner} T{var.clearance} O{var.overtravel} P{var.probeDepth} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition}
