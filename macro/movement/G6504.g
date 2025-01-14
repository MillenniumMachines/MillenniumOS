; G6504.g: PROBE WORK PIECE - WEB
;
; Meta macro to gather operator input before executing a
; web probe cycle (G6504.1).
; The macro will explain to the operator what is about to
; happen and ask for an approximate length and width of
; the web. The macro will then ask the operator to jog
; the probe over the approximate center of the web, and
; enter a probe depth. These values will then be passed
; to the underlying G6504.1 macro to execute the probe cycle.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Display description of web probe if not already displayed this session
if { global.mosTM && !global.mosDD[6] }
    M291 P"This probe cycle finds the X or Y co-ordinates of the midpoint of a web (protruding feature) on a workpiece by probing towards the web surfaces from each side." R"MillenniumOS: Probe Web " T0 S2
    M291 P"You will be asked to enter an approximate <b>width</b> and optionally <b>length</b> of the web, and a <b>clearance distance</b>." R"MillenniumOS: Probe Web" T0 S2
    M291 P"These define how far the probe will move away from the starting point before moving downwards and probing back towards the relevant surfaces." R"MillenniumOS: Probe Web" T0 S2
    M291 P"You will then jog the tool over the approximate midpoint of the web.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Web" T0 S2
    M291 P"Finally, you will be asked for a <b>probe depth</b>. This is how far the probe will move downwards before probing towards the midpoint." R"MillenniumOS: Probe Web" T0 S2
    M291 P"If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/web-xy"">View the Web Documentation</a> for more details." R"MillenniumOS: Probe Web" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Web probe aborted!" }
    set global.mosDD[6] = true

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

M291 P{"Please select the probing mode to use.<br/><b>Full</b> will probe 2 points on each surface of the web, while <b>Quick</b> will probe only 1 point."} R"MillenniumOS: Web" J2 T0 S4 K{"Full","Quick"} F0
if { result != 0 }
    abort { "Web probe aborted!" }

var mode = { input }

M291 P{"Please select the orientation of the web.<br/><b>X</b> probes 2 surfaces forming the web perpendicular to the X axis, <b>Y</b> probes 2 surfaces perpendicular to the Y axis."} R"MillenniumOS: Web" J2 T0 S4 K{"X","Y"}
if { result != 0 }
    abort { "Web probe aborted!" }

var axis = { input }
var webLetter = { (var.axis == 0) ? "X" : "Y" }
var lengthLetter = { (var.axis == 0) ? "Y" : "X" }

var bW = { (global.mosWPDims[var.workOffset][0] != null) ? global.mosWPDims[var.workOffset][0] : 100 }

M291 P{"Please enter approximate <b>web width</b> in mm.<br/><b>NOTE</b>: <b>Width</b> is measured along the <b>" ^ var.webLetter ^ " axis."} R"MillenniumOS: Probe Web" J1 T0 S6 F{var.bW}
if { result != 0 }
    abort { "Web probe aborted!" }

var webWidth = { input }

if { var.webWidth < 1 }
    abort { "Web width too low!" }

var webLength = { null }

; 0 = Full mode, 1 = Quick mode
; Only prompt for length if in full mode
if { var.mode == 0 }
    var bL = { (global.mosWPDims[var.workOffset][1] != null) ? global.mosWPDims[var.workOffset][1] : 100 }

    M291 P{"Please enter approximate <b>web length</b> in mm.<br/><b>NOTE</b>: <b>Length</b> is measured along the <b>" ^ var.lengthLetter ^ "</b> axis."} R"MillenniumOS: Probe Web" J1 T0 S6 F{var.bL}
    if { result != 0 }
        abort { "Web probe aborted!" }

    set var.webLength = { input }

    if { var.webLength < 1 }
        abort { "Web length too low!" }

; Prompt for clearance distance
M291 P"Please enter <b>clearance</b> distance in mm.<br/>This is how far away from the expected surfaces and corners we probe from, to account for any innaccuracy in the start position." R"MillenniumOS: Probe Web" J1 T0 S6 F{global.mosCL}
if { result != 0 }
    abort { "Web probe aborted!" }

var surfaceClearance = { input }

if { var.surfaceClearance <= 0.1 }
    abort { "Clearance distance too low!" }

var edgeClearance = null

; 0 = Full mode, 1 = Quick mode
; Only check for edge clearance if in full mode
if { var.mode == 0 }
    ; Calculate the maximum clearance distance we can use before
    ; the probe points will be flipped
    var mC = { min(var.webWidth, var.webLength) / 2 }

    if { var.surfaceClearance >= var.mC }
        var defCC = { max(1, var.mC-1) }
        M291 P{"The <b>clearance</b> distance is more than half of the length of the web.<br/>Please enter an <b>edge clearance</b> distance less than <b>" ^ var.mC ^ "</b>."} R"MillenniumOS: Probe Web" J1 T0 S6 F{var.defCC}
        set var.edgeClearance = { input }
        if { var.edgeClearance >= var.mC }
            abort { "Edge clearance distance too high!" }

; Prompt for overtravel distance
M291 P"Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surfaces to account for any innaccuracy in the dimensions." R"MillenniumOS: Probe Web" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Web probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0.1 }
    abort { "Overtravel distance too low!" }

M291 P"Please jog the probe <b>OVER</b> the approximate midpoint of the web and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" R"MillenniumOS: Probe Web" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Web probe aborted!" }

M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards." R"MillenniumOS: Probe Web" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Web probe aborted!" }

var probingDepth = { input }

if { var.probingDepth < 0 }
    abort { "Probing depth was negative!" }

; Run the web probe cycle
if { global.mosTM }
    M291 P{"Probe will now move outside each surface and down by " ^ var.probingDepth ^ "mm, before probing towards the midpoint."} R"MillenniumOS: Probe Web" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Web probe aborted!" }

; Get current machine position
M5000 P0

G6504.1 W{var.workOffset} Q{var.mode} N{var.axis} H{var.webWidth} I{var.webLength} T{var.surfaceClearance} C{var.edgeClearance} O{var.overtravel} J{global.mosMI[0]} K{global.mosMI[1]} L{global.mosMI[2]} Z{global.mosMI[2] - var.probingDepth}
