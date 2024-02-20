; G6502.g: PROBE WORK PIECE - RECTANGLE POCKET
;
; Meta macro to gather operator input before executing a
; rectangular pocket probe cycle (G6502.1).
; The macro will explain to the operator what is about to
; happen and ask for an approximate length and width of
; the pocket. The macro will then ask the operator to jog
; the probe over the approximate center of the pocket, and
; enter a probe depth. These values will then be passed
; to the underlying G6502.1 macro to execute the probe cycle.

; Display description of rectangle pocket probe if not already displayed this session
if { global.mosTutorialMode && !global.mosDescDisplayed[6] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a rectangular pocket (recessed feature) on a workpiece by moving into the pocket and probing towards each surface." R"MillenniumOS: Probe Rect. Pocket " T0 S2
    M291 P"You will be asked to enter an approximate <b>width</b> and <b>height</b> of the pocket, and a <b>clearance distance</b>." R"MillenniumOS: Probe Rect. Pocket" T0 S2
    M291 P"These define how far the probe will move away from the center point before starting to probe towards the relevant surfaces." R"MillenniumOS: Probe Rect. Pocket" T0 S2
    M291 P"You will then jog the tool over the approximate center of the pocket.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Rect. Pocket" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards into the pocket before probing towards the edges. Press ""OK"" to continue." R"MillenniumOS: Probe Rect. Pocket" T0 S3
    if { result != 0 }
        abort { "Rectangle pocket probe aborted!" }
    set global.mosDescDisplayed[6] = true

; Make sure probe tool is selected
if { global.mosProbeToolID != state.currentTool }
    T T{global.mosProbeToolID}

var bW = { (global.mosWorkPieceDimensions[0] != null) ? global.mosWorkPieceDimensions[0] : 100 }

M291 P{"Please enter approximate <b>pocket width</b> in mm.<br/><b>NOTE</b>: <b>Width</b> is measured along the <b>X</b> axis."} R"MillenniumOS: Probe Rect. Pocket" J1 T0 S6 F{var.bW}
if { result != 0 }
    abort { "Rectangle pocket probe aborted!" }
else
    var pocketWidth = { input }

    if { var.pocketWidth < 1 }
        abort { "Pocket width too low!" }

    var bL = { (global.mosWorkPieceDimensions[1] != null) ? global.mosWorkPieceDimensions[1] : 100 }

    M291 P{"Please enter approximate <b>pocket length</b> in mm.<br/><b>NOTE</b>: <b>Length</b> is measured along the <b>Y</b> axis."} R"MillenniumOS: Probe Rect. Pocket" J1 T0 S6 F{var.bL}
    if { result != 0 }
        abort { "Rectangle pocket probe aborted!" }
    else
        var pocketLength = { input }

        if { var.pocketLength < 1 }
            abort { "Pocket length too low!" }

        ; Prompt for clearance distance
        M291 P"Please enter <b>clearance</b> distance in mm.<br/>This is how far out we move from the expected surfaces to account for any innaccuracy in the center location." R"MillenniumOS: Probe Rect. Pocket" J1 T0 S6 F{global.mosProbeClearance}
        if { result != 0 }
            abort { "Rectangle pocket probe aborted!" }
        else
            var clearance = { input }
            if { var.clearance < 1 }
                abort { "Clearance distance too low!" }

            ; Prompt for overtravel distance
            M291 P"Please enter <b>overtravel</b> distance in mm.<br/>This is how far in we move from the expected surfaces to account for any innaccuracy in the dimensions." R"MillenniumOS: Probe Rect. Pocket" J1 T0 S6 F{global.mosProbeOvertravel}
            if { result != 0 }
                abort { "Rectangle pocket probe aborted!" }
            else
                var overtravel = { input }
                if { var.overtravel < 0.1 }
                    abort { "Overtravel distance too low!" }

                M291 P"Please jog the probe <b>OVER</b> the center of the rectangle pocket and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" R"MillenniumOS: Probe Rect. Pocket" X1 Y1 Z1 J1 T0 S3
                if { result != 0 }
                    abort { "Rectangle pocket probe aborted!" }
                else
                    M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards." R"MillenniumOS: Probe Rect. Pocket" J1 T0 S6 F{global.mosProbeOvertravel}
                    if { result != 0 }
                        abort { "Rectangle pocket probe aborted!" }
                    else
                        var probingDepth = { input }

                        if { var.probingDepth < 0 }
                            abort { "Probing depth was negative!" }

                        ; Run the pocket probe cycle
                        if { global.mosTutorialMode }
                            M291 P{"Probe will now move down by " ^ var.probingDepth ^ "mm, before probing towards each of the pocket surfaces at 2 locations."} R"MillenniumOS: Probe Rect. Pocket" T0 S3
                            if { result != 0 }
                                abort { "Rectangle pocket probe aborted!" }

                        G6502.1 W{exists(param.W)? param.W : null} H{var.pocketWidth} I{var.pocketLength} T{var.clearance} O{var.overtravel} J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probingDepth}
