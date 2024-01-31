; G6500.g: PROBE WORK PIECE - BORE
;
; Meta macro to gather operator input before executing a
; bore probe cycle (G6500.1). The macro will explain to
; the operator what is about to happen and ask for an
; approximate bore diameter. The macro will then ask the
; operator to jog the probe into the center of the bore
; and hit OK, at which point the bore probe cycle will
; be executed.

; Display description of bore probe if not already displayed this session
if { !global.mosExpertMode && !global.mosDescBoreDisplayed }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a circular bore (hole) in a workpiece by moving downwards into the bore and probing outwards in 3 directions." R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will be asked to enter an approximate <b>bore diameter</b> and <b>overtravel distance</b>.<br/>These define how far the probe will move from the centerpoint, without being triggered, before erroring." R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will then jog the touch probe over the approximate center of the bore.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could damage the probe if moving in the wrong direction!" R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards into the bore before probing outwards. Press ""OK"" to continue." R"MillenniumOS: Probe Bore" T0 S3
    if { result != 0 }
        abort { "Bore probe aborted!" }
        M99
    set global.mosDescBoreDisplayed = true

var needsTouchProbe = { global.mosTouchProbeToolID != null && global.mosTouchProbeToolID != state.currentTool }
if { var.needsTouchProbe }
    T T{global.mosTouchProbeToolID}

; Prompt for bore diameter
M291 P"Please enter approximate bore diameter in mm." R"MillenniumOS: Probe Bore" J1 T0 S6 F6.0
if { result != 0 }
    abort { "Bore probe aborted!" }
    M99
else
    var boreDiameter = { input }

    ; Prompt for overtravel distance
    M291 P"Please enter overtravel distance in mm." R"MillenniumOS: Probe Bore" J1 T0 S6 F{global.mosProbeOvertravel}
    if { result != 0 }
        abort { "Bore probe aborted!" }
        M99
    else
        var overTravel = { input }
        M291 P"Please jog the probe OVER the approximate center of the bore and press OK." R"MillenniumOS: Probe Bore" X1 Y1 Z1 J1 T0 S3
        if { result != 0 }
            abort { "Bore probe aborted!" }
            M99
        else
            M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing outwards." R"MillenniumOS: Probe Bore" J1 T0 S6 F{global.mosProbeOvertravel}
            if { result != 0 }
                abort { "Bore probe aborted!" }
                M99
            else
                var probingDepth = { input }

                if { var.probingDepth < 0}
                    abort { "Probing depth was negative!" }
                    M99

                ; Run the bore probe cycle
                if { !global.mosExpertMode }
                    M291 P{"Probe will now move downwards " ^ var.probingDepth ^ "mm into the bore and probe towards the edge in 3 directions."} R"MillenniumOS: Probe Bore" J1 T0 S3
                    if { result != 0 }
                        abort { "Bore probe aborted!" }
                        M99

                G6500.1 W{param.W} H{var.boreDiameter} O{var.overTravel} J{move.axes[global.mosIX].machinePosition} K{move.axes[global.mosIY].machinePosition} L{move.axes[global.mosIZ].machinePosition - var.probingDepth}
