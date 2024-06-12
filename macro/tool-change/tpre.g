; tpre.g: PRE TOOL CHANGE - EXECUTE
; Called before the tool change to trigger guidance
; to the operator.

; This is a generalised pre-tool-change script
; that has access to both the current and 'new'
; tool information. It is called automatically when
; executing T<n> without any additional parameters
; to block tool change macros.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Abort if no tool selected
if { state.nextTool < 0 }
    M99

; Abort if not homed
if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    M99

; If tfree ran to completion or was not run (no previous tool was loaded)
; then we can continue.
; We also allow running if tpre did not run to completion last time, as a
; subsequent successful tool change will bring the machine back to a consistent
; state. Failed tool changes will cause a job to abort anyway.
if { global.mosTCS != null && global.mosTCS < 1 }
    abort { "tfree.g did not run to completion, aborting tpre.g"}

; Set tool change state to starting tpre
set global.mosTCS = 2

; Stop and park the spindle
G27 Z1

; Check if we're switching to a probe.
if { state.nextTool == global.mosPTID }
    ; If touch probe is enabled, prompt the operator to install
    ; it and check for activation.
    if { global.mosFeatTouchProbe }
        M291 P{"Please install your <b>Touch Probe</b> into the spindle and make sure it is connected.<br/>When ready, press <b>Continue</b>, and then manually activate it until it is detected."} R"MillenniumOS: Probe Tool" S4 K{"Continue", "Cancel"}
        if { input != 0 }
            abort { "Tool change aborted by operator!" }

        echo { "Waiting for touch probe activation... "}

        ; Wait for a 100ms activation of the touch probe for a maximum of 30s
        M8002 K{global.mosTPID} D100 W30

        ; Check if requested probe ID was detected.
        if { global.mosPD != global.mosTPID }
            abort {"Did not detect a <b>Touch Probe</b> with ID " ^ global.mosTPID ^ "! Please check your Probe connection and run T" ^ global.mosPTID ^ " again to verify it is connected."}
    else
        ; If no touch probe enabled, ask user to install datum tool.
        M291 P{"Please install your <b>Datum Tool</b> into the spindle. When ready, press <b>Continue</b>."} R"MillenniumOS: Probe Tool" S4 K{"Continue", "Cancel"}
        if { input != 0 }
            abort { "Tool change aborted by operator, aborting job!" }
        echo { "Touch Probe feature disabled, manual probing will use an installed datum tool." }
else

    if { global.mosFeatTouchProbe && global.mosFeatToolSetter && global.mosTSAP == null }
        abort { "Touch Probe and Toolsetter are enabled but reference surface has not been probed. Please run G6511 first, then switch back to this tool using T" ^ state.nextTool ^ "."}

    ; All other tools cannot be detected so we just have to
    ; trust the operator did the right thing given the
    ; information :)
    if { global.mosTM && !global.mosDD[13] }
        M291 P{"A tool change is required. You will be asked to insert the correct tool, and then the tool length will be probed."} R"MillenniumOS: Tool Change" S2 T0

        if { global.mosFeatToolSetter && global.mosTT[state.nextTool][0] > global.mosTSR }
            var dH = sensors.probes[global.mosTSID].diveHeights[0]
            M291 P"The next tool is bigger than your toolsetter, so we need to perform offset radius probing. We will probe the center of the tool once, then probe around the radius to detect the lowest point." R"MillenniumOS: Tool Change" S2 T0
            M291 P"Please ensure the center of the tool is no higher than " ^ var.dH ^ "mm from the lowest point, and adjust the <b>dive height</b> of your toolsetter (<b>M558 H...</b> in RRF) if so." R"MillenniumOS: Tool Change" S2 T0
            M291 P"You can read more about how radius offset probing works <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/radius-offset-probing"">here</a>." R"MillenniumOS: Tool Change" S2 T0

        M291 P"If you are unsure about this, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/tool-changes"">View the Tool Change Documentation</a> for more details." R"MillenniumOS: Tool Change" S2 T0
        set global.mosDD[13] = true

    ; Prompt user to change tool
    M291 P{"Insert Tool <b>#" ^ state.nextTool ^ "</b>: " ^ tools[state.nextTool].name ^ " and press <b>Continue</b> when ready. <b>Cancel</b> will abort the running job!"} R"MillenniumOS: Tool Change" S4 K{"Continue", "Cancel"}
    if { input != 0 }
        abort { "Tool change aborted by operator!" }

; Set tool change state to tpre complete
set global.mosTCS = 3

