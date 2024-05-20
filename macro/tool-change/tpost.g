; tpost.g: POST TOOL CHANGE - EXECUTE
;
; Called after the tool change, can be used
; to probe tool length or reference surface
; position if touch probe is installed.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Abort if no tool selected
if { state.currentTool < 0 }
    M99

; Abort if not homed
if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    M99

; tpre _must_ have run to completion before we execute any post-change
; operations. If it didn't, we abort this file.
if { global.mosTCS == null || global.mosTCS < 3 }
    abort { "tpre.g did not run to completion, aborting tpost.g"}

set global.mosTCS = 4

; Stop and park the spindle
G27 Z1

; If touch probe is current tool, and enabled, and we have not calculated
; the toolsetter activation position yet, then run G6511 to probe the
; reference surface so we can make this calculation.
; Touchprobe tool ID is only set if the touchprobe feature is enabled.
if { state.currentTool == global.mosPTID }

    ; We only need to probe the reference surface with both toolsetter and
    ; touch probe activated. If the toolsetter is not activated, we can't
    ; compensate for tool lengths automatically so we need to re-set Z origin
    ; on each tool change.
    if { global.mosFeatTouchProbe && global.mosFeatToolSetter }
        ; We abort the tool change if the touch probe is not detected
        ; so at this point we can safely assume the probe is connected.
        M291 P{"<b>Touch Probe Detected</b>.<br/>We will now probe the reference surface. Move away from the machine <b>BEFORE</b> pressing <b>OK</b>!"} R"MillenniumOS: Tool Change" S2
        ; Call reference surface probe in non-standalone mode to
        ; run the actual probe, and force a re-probe if already set
        ; since the probe has been re-installed, the measured distance
        ; will be different.
        G6511 S0 R1
        if { global.mosTSAP == null }
            abort { "Touch probe reference surface probe failed." }
    ; If the toolsetter is enabled but not the touch probe, then we asked
    ; the operator to install the datum tool, and we need to know its length
    ; so we can compensate automatically on tool change.
    elif { global.mosFeatToolSetter }
            M291 P{"<b>Datum Tool Installed</b>.<br/>We will now probe the tool length. Move away from the machine <b>BEFORE</b> pressing <b>OK</b>!"} R"MillenniumOS: Tool Change" S2

        ; Probe datum tool length
        G37
elif { global.mosFeatToolSetter }
    ; Probe non-probe tool length using the toolsetter
    G37
else
    ; Probe Z origin using installed tool
    G37.1

set global.mosTCS = null