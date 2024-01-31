; tpost.g: POST TOOL CHANGE - EXECUTE
;
; Called after the tool change, can be used
; to probe tool length or reference surface
; position if touch probe is installed.

var tI = { state.currentTool }
if { var.tI < 0 }
    M99

if { !move.axes[global.mosIX].homed || !move.axes[global.mosIY].homed || !move.axes[global.mosIZ].homed }
    M99

; Stop and park the spindle
G27 Z1

; If touch probe is current tool, and enabled, and we have not calculated
; the toolsetter activation position yet, then run G6511 to probe the
; reference surface so we can make this calculation.
; Touchprobe tool ID is only set if the touchprobe feature is enabled.
if { var.tI == global.mosTouchProbeToolID }
    if { global.mosToolSetterActivationPos == null }
        M291 P{"Touch probe active. Press OK to probe reference surface."} R"MillenniumOS: Tool Change" S2
        G6511
    elif { !global.mosExpertMode }
        echo { "MillenniumOS: Touch probe active, reference surface already probed." }
else
    ; Probe non-touchprobe tool length
    G37

    ; Continue after operator confirmation if necessary
    if { !global.mosExpertMode }
        M291 P{"Tool change complete. Press Continue to start the next operation, or Pause to perform further manual tasks (e.g. workpiece fixture changes)"} R"MillenniumOS: Tool Change" S4 K{"Continue", "Pause"}
        if { input != 0 }
            M25.9 S{"Operator paused job after tool change complete." }