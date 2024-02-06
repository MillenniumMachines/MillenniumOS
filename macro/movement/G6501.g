; G6501.g: PROBE WORK PIECE - BOSS
;
; Meta macro to gather operator input before executing a
; boss probe cycle (G6501.1). The macro will explain to
; the operator what is about to happen and ask for an
; approximate boss diameter. The macro will then ask the
; operator to jog the probe into the center of the boss
; and then ask for a probing depth. These values are then
; passed to the G6501.1 macro to execute the boss probe.

; Display description of boss probe if not already displayed this session
if { !global.mosExpertMode && !global.mosDescDisplayed[3] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a circular boss (protruding feature) on a workpiece by probing towards the approximate center of the boss in 3 directions." R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will be asked to enter an approximate <b>boss diameter</b> and <b>clearance distance</b>.<br/>These define how far the probe will move away from the centerpoint before probing back inwards." R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will then jog the tool over the approximate center of the boss.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards after moving outside of the boss diameter, and before probing towards the centerpoint. Press ""OK"" to continue." R"MillenniumOS: Probe Boss" T0 S3
    if { result != 0 }
        abort { "Boss probe aborted!" }
    set global.mosDescDisplayed[3] = true

var needsProbeTool = { global.mosProbeToolID != state.currentTool }
if { var.needsProbeTool }
    T T{global.mosProbeToolID}

; Prompt for boss diameter
M291 P"Please enter approximate boss diameter in mm." R"MillenniumOS: Probe Boss" J1 T0 S6 F6.0
if { result != 0 }
    abort { "Boss probe aborted!" }
else
    var bossDiameter = { input }

    ; Prompt for clearance distance
    M291 P"Please enter clearance distance in mm." R"MillenniumOS: Probe Boss" J1 T0 S6 F{global.mosProbeClearance}
    if { result != 0 }
        abort { "Boss probe aborted!" }
    else
        var clearance = { input }
        M291 P"Please jog the probe OVER the approximate center of the boss and press OK." R"MillenniumOS: Probe Boss" X1 Y1 Z1 J1 T0 S3
        if { result != 0 }
            abort { "Boss probe aborted!" }
        else
            M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards." R"MillenniumOS: Probe Boss" J1 T0 S6 F{global.mosProbeOvertravel}
            if { result != 0 }
                abort { "Boss probe aborted!" }
            else
                var probingDepth = { input }

                if { var.probingDepth < 0}
                    abort { "Probing depth was negative!" }

                ; Run the boss probe cycle
                if { !global.mosExpertMode }
                    M291 P{"Probe will now move outwards by " ^ {(var.bossDiameter/2) + var.clearance} ^ "mm and then downwards " ^ var.probingDepth ^ "mm, before probing towards the edge in 3 directions."} R"MillenniumOS: Probe Boss" T0 S3
                    if { result != 0 }
                        abort { "Boss probe aborted!" }

                G6501.1 W{param.W} H{var.bossDiameter} T{var.clearance} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probingDepth}
