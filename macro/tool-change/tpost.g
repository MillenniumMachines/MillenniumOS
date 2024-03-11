; tpost.g: POST TOOL CHANGE - EXECUTE
;
; Called after the tool change, can be used
; to probe tool length or reference surface
; position if touch probe is installed.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Make sure we're in the default motion system
M598

; tpre _must_ have run to completion before we execute any post-change
; operations. If it didn't, we abort this file.
if { global.mosTCS != 3 }
    abort {"MillenniumOS: tpre.g did not run to completion, aborting tpost.g"}

set global.mosTCS = 4

; Abort if no tool selected
if { state.currentTool < 0 }
    M99

; Abort if not homed
if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    M99

; Stop and park the spindle
G27 Z1

; If touch probe is current tool, and enabled, and we have not calculated
; the toolsetter activation position yet, then run G6511 to probe the
; reference surface so we can make this calculation.
; Touchprobe tool ID is only set if the touchprobe feature is enabled.
if { state.currentTool == global.mosPTID }
    if { global.mosFeatTouchProbe }
        ; We abort the tool change if the touch probe is not detected
        ; so at this point we can safely assume the probe is connected.
        M291 P{"<b>Touch Probe Detected</b>.<br/>We will now probe the reference surface. Move away from the machine <b>BEFORE</b> pressing <b>OK</b>!"} R"MillenniumOS: Tool Change" S2
        ; Call reference surface probe in non-standalone mode to
        ; run the actual probe.
        G6511 S0 R1
        if { global.mosTSAP == null }
            abort { "Touch probe reference surface probing failed." }
    else
            M291 P{"<b>Datum Tool Installed</b>.<br/>We will now probe the tool length. Move away from the machine <b>BEFORE</b> pressing <b>OK</b>!"} R"MillenniumOS: Tool Change" S2

        ; Probe datum tool length
        G37
else
    ; Probe non-probe tool length
    G37

; Continue after operator confirmation if necessary
if { !global.mosEM }
    if { job.file.fileName != null }
        M291 P{"Tool change complete. Press Continue to start the next operation, or Pause to perform further manual tasks (e.g. workpiece fixture changes)"} R"MillenniumOS: Tool Change" S4 K{"Continue", "Pause"}
        if { input != 0 }
            echo { "Operator paused job after tool change complete." }
            M25
    else
        M291 P{"Tool change complete. Press <b>OK</b> to continue!"} R"MillenniumOS: Tool Change" S2 T0

set global.mosTCS = null