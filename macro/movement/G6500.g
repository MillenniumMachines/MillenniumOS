; G6500.g: PROBE WORK PIECE - BORE
;
; Meta macro to gather operator input before executing a
; bore probe cycle (G6500.1). The macro will explain to
; the operator what is about to happen and ask for an
; approximate bore diameter. The macro will then ask the
; operator to jog the probe into the center of the bore
; and enter a probing depth. These values are then passed
; to G6500.1 to execute the bore probe cycle.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Display description of bore probe if not already displayed this session
if { global.mosTM && !global.mosDD[2] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a circular bore (hole) in a workpiece by moving downwards into the bore and probing outwards in 3 directions." R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will be asked to enter an approximate <b>bore diameter</b> and <b>overtravel distance</b>.<br/>These define how far the probe will move from the centerpoint, without being triggered, before erroring." R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will then jog the tool over the approximate center of the bore.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards into the bore before probing outwards." R"MillenniumOS: Probe Bore" T0 S2
    M291 P"If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/circular-bore"">View the Circular Bore Documentation</a> for more details." R"MillenniumOS: Probe Bore" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Bore probe aborted!" }
    set global.mosDD[2] = true

; Make sure probe tool is selected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Note: These if's below are nested for a reason.
; During a print file, sometimes the lines after an M291 are executed
; before the M291 has been acknowledged by the operator. This is bad.
; We nest the ifs to make sure that the subsequent code is run only
; after the M291 has been acknowledged.

; Prompt for bore diameter
M291 P"Please enter approximate bore diameter in mm." R"MillenniumOS: Probe Bore" J1 T0 S6 F{(global.mosWPRad != null) ? global.mosWPRad*2 : 0}
if { result != 0 }
    abort { "Bore probe aborted!" }

var boreDiameter = { input }

if { var.boreDiameter < 1 }
    abort { "Bore diameter too low!" }


; Prompt for overtravel distance
M291 P"Please enter overtravel distance in mm." R"MillenniumOS: Probe Bore" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Bore probe aborted!" }

var overTravel = { input }
if { var.overTravel < 0.1 }
    abort { "Overtravel distance too low!" }

M291 P"Please jog the probe <b>OVER</b> the center of the bore and press <b>OK</b>." R"MillenniumOS: Probe Bore" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Bore probe aborted!" }

M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing outwards." R"MillenniumOS: Probe Bore" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    abort { "Bore probe aborted!" }

var probingDepth = { input }

if { var.probingDepth < 0 }
    abort { "Probing depth was negative!" }

; Run the bore probe cycle
if { global.mosTM }
    M291 P{"Probe will now move downwards " ^ var.probingDepth ^ "mm into the bore then probe towards the edge in 3 directions."} R"MillenniumOS: Probe Bore" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Bore probe aborted!" }

G6500.1 W{exists(param.W)? param.W : null} H{var.boreDiameter} O{var.overTravel} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probingDepth}
