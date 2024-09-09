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

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

var bW = { (global.mosWPDims[var.workOffset][0] != null) ? global.mosWPDims[var.workOffset][0] : 100 }

M291 P{"Please enter approximate <b>block width</b> in mm.<br/><b>NOTE</b>: <b>Width</b> is measured along the <b>X</b> axis."} R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{var.bW}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var blockWidth = { input }

if { var.blockWidth < 1 }
    abort { "Block width too low!" }

var bL = { (global.mosWPDims[var.workOffset][1] != null) ? global.mosWPDims[var.workOffset][1] : 100 }

M291 P{"Please enter approximate <b>block length</b> in mm.<br/><b>NOTE</b>: <b>Length</b> is measured along the <b>Y</b> axis."} R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{var.bL}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var blockLength = { input }

if { var.blockLength < 1 }
    abort { "Block length too low!" }

; Prompt for clearance distance
M291 P"Please enter <b>clearance</b> distance in mm.<br/>This is how far away from the expected surfaces and corners we probe from, to account for any innaccuracy in the start position." R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{global.mosCL}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var surfaceClearance = { input }

if { var.surfaceClearance <= 0.1 }
    abort { "Clearance distance too low!" }

; Calculate the maximum clearance distance we can use before
; the probe points will be flipped
var mC = { min(var.blockWidth, var.blockLength) / 2 }

var cornerClearance = null

if { var.surfaceClearance >= var.mC }
    var defCC = { max(1, var.mC-1) }
    M291 P"The <b>clearance</b> distance is more than half of the length or width of the block.<br/>Please enter a <b>corner clearance</b> distance less than <b>" ^ var.mC ^ "</b>." R"MillenniumOS: Probe Rect. Block" J1 T0 S6 F{var.defCC}
    set var.cornerClearance = { input }
    if { var.cornerClearance >= var.mC }
        abort { "Corner clearance distance too high!" }

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

; Get current machine position
M5000 P0

G6503.1 W{var.workOffset} H{var.blockWidth} I{var.blockLength} T{var.surfaceClearance} C{var.cornerClearance} O{var.overtravel} J{global.mosMI[0]} K{global.mosMI[1]} L{global.mosMI[2] - var.probingDepth}
