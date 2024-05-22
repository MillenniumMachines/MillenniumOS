; G6501.g: PROBE WORK PIECE - BOSS
;
; Meta macro to gather operator input before executing a
; boss probe cycle (G6501.1). The macro will explain to
; the operator what is about to happen and ask for an
; approximate boss diameter. The macro will then ask the
; operator to jog the probe into the center of the boss
; and then ask for a probing depth. These values are then
; passed to the G6501.1 macro to execute the boss probe.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Display description of boss probe if not already displayed this session
if { global.mosTM && !global.mosDD[3] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a circular boss (protruding feature) on a workpiece by probing towards the approximate center of the boss in 3 directions." R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will be asked to enter an approximate <b>boss diameter</b> and <b>clearance distance</b>.<br/>These define how far the probe will move away from the centerpoint before probing back inwards." R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will then jog the tool over the approximate center of the boss.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards before probing back towards the centerpoint." R"MillenniumOS: Probe Boss" T0 S2
    M291 P"If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/circular-boss"">View the Circular Boss Documentation</a> for more details." R"MillenniumOS: Probe Boss" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Boss probe aborted!" }
    set global.mosDD[3] = true

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Prompt for boss diameter
M291 P"Please enter approximate boss diameter in mm." R"MillenniumOS: Probe Boss" J1 T0 S6 F{(global.mosWPRad != null) ? global.mosWPRad*2 : 0}
if { result != 0 }
    abort { "Boss probe aborted!" }

var bossDiameter = { input }

if { var.bossDiameter < 1 }
    abort { "Boss diameter too low!" }

; Prompt for clearance distance
M291 P"Please enter clearance distance in mm." R"MillenniumOS: Probe Boss" J1 T0 S6 F{global.mosCL}
if { result != 0 }
    abort { "Boss probe aborted!" }

var clearance = { input }
if { var.clearance < 1 }
    abort { "Clearance distance too low!" }

; Prompt for overtravel distance
M291 P"Please enter the overtravel distance in mm." R"MillenniumOS: Probe Boss" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Boss probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0.1 }
    abort { "Overtravel distance too low!" }

M291 P"Please jog the probe <b>OVER</b> the center of the boss and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" R"MillenniumOS: Probe Boss" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Boss probe aborted!" }

M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards." R"MillenniumOS: Probe Boss" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Boss probe aborted!" }

var probingDepth = { input }

if { var.probingDepth <= 0}
    abort { "Probing depth was negative!" }

; Run the boss probe cycle
if { global.mosTM }
    M291 P{"Probe will now move outwards by " ^ {(var.bossDiameter/2) + var.clearance} ^ "mm, then downwards " ^ var.probingDepth ^ "mm, before probing back towards the center at 3 points."} R"MillenniumOS: Probe Boss" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Boss probe aborted!" }

G6501.1 W{exists(param.W)? param.W : null} H{var.bossDiameter} T{var.clearance} O{var.overtravel} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probingDepth}
