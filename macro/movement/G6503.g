; G6503.g: PROBE WORK PIECE - RECTANGLE BLOCK
;
; Meta macro to gather operator input before executing a
; rectangular block probe cycle (G6503.1).
; The macro will explain to the operator what is about to
; happen and ask for an approximate length and width of
; the block. The macro will then ask the operator to jog
; the probe over the approximate center of the block, and
; enter a probe depth. These values will then be passed
; to the underlying G6503.1 macro to execute the probe cycle.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Display description of rectangle block probe if not already displayed this session
if { global.mosTM && !global.mosDD[5] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a rectangular block (protruding feature) on a workpiece by probing towards the block surfaces from all 4 directions." R"MillenniumOS: Probe Rect. Block " T0 S2
    M291 P"You will be asked to enter an approximate <b>width</b> and <b>length</b> of the block, and a <b>clearance distance</b>." R"MillenniumOS: Probe Rect. Block" T0 S2
    M291 P"These define how far the probe will move away from the center point before moving downwards and probing back towards the relevant surfaces." R"MillenniumOS: Probe Rect. Block" T0 S2
    M291 P"You will then jog the tool over the approximate center of the block.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Rect. Block" T0 S2
    M291 P"Finally, you will be asked for a <b>probe depth</b>. This is how far the probe will move downwards before probing towards the centerpoint." R"MillenniumOS: Probe Rect. Block" T0 S2
    M291 P"If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/rectangle-block"">View the Rectangle Block Documentation</a> for more details." R"MillenniumOS: Probe Rect. Block" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Rectangle block probe aborted!" }
    set global.mosDD[5] = true

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

var bW = { (global.mosWPDims[0] != null) ? global.mosWPDims[0] : 100 }

M291 P{"Please enter approximate <b>block width</b> in mm.<br/><b>NOTE</b>: <b>Width</b> is measured along the <b>X</b> axis."} R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{var.bW}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var blockWidth = { input }

if { var.blockWidth < 1 }
    abort { "Block width too low!" }

var bL = { (global.mosWPDims[1] != null) ? global.mosWPDims[1] : 100 }

M291 P{"Please enter approximate <b>block length</b> in mm.<br/><b>NOTE</b>: <b>Length</b> is measured along the <b>Y</b> axis."} R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{var.bL}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var blockLength = { input }

if { var.blockLength < 1 }
    abort { "Block length too low!" }

; Prompt for clearance distance
M291 P"Please enter <b>clearance</b> distance in mm.<br/>This is how far away from the expected surfaces we start probing from, to account for any innaccuracy in the center location." R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{global.mosCL}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var clearance = { input }

if { var.clearance < 1 }
    abort { "Clearance distance too low!" }

; Prompt for overtravel distance
M291 P"Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surfaces to account for any innaccuracy in the dimensions." R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0.1 }
    abort { "Overtravel distance too low!" }

M291 P"Please jog the probe <b>OVER</b> the center of the rectangle block and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" R"MillenniumOS: Probe Rect. Block" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards." R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var probingDepth = { input }

if { var.probingDepth < 0 }
    abort { "Probing depth was negative!" }

; Run the block probe cycle
if { global.mosTM }
    M291 P{"Probe will now move outside each surface and down by " ^ var.probingDepth ^ "mm, before probing towards the center."} R"MillenniumOS: Probe Rect. Block" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Rectangle block probe aborted!" }

G6503.1 W{exists(param.W)? param.W : null} H{var.blockWidth} I{var.blockLength} T{var.clearance} O{var.overtravel} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probingDepth}
