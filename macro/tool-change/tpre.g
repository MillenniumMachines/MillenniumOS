; tpre.g: PRE TOOL CHANGE - EXECUTE
; Called before the tool change to trigger guidance
; to the operator.

; This is a generalised pre-tool-change script
; that has access to both the current and 'new'
; tool information. It is called automatically when
; executing T<n> without any additional parameters
; to block tool change macros.

var tI = { state.nextTool }
if { var.tI < 0 }
    abort {"No tool selected!"}
    M99

if { !move.axes[global.mosIX].homed || !move.axes[global.mosIY].homed || !move.axes[global.mosIZ].homed }
    abort {"Machine must be homed before executing a tool change."}
    T-1 P0
    M99

; Stop and park the spindle
G27 Z1

var tD = {(exists(tools[var.tI])) ? tools[var.tI].name : "Unknown Tool" }

; Check if we're switching to a touch probe.
; If the touch probe feature is enabled, then
; make sure the operator has connected it by
; waiting for a manual activation.
if { var.tI == global.mosTouchProbeToolID }
    if { !global.mosFeatureTouchProbe }
        if { !global.mosExpertMode }
            M291 P{"The touch probe feature is disabled. You can still use canned probing cycles, but these will walk you through a manual probing process."} R"MillenniumOS: Touch Probe" S2 T0
        echo { "Touch probe feature disabled, manual probing required!" }
        ; TODO: Explain to operator the manual probing procedure
        M99

    M291 P{"Please install your touch probe into the spindle and make sure it is connected.<br/>When ready, press <b>OK</b>, and then manually activate your touch probe until it is detected."} R"MillenniumOS: Touch Probe" S2 T0

    echo { "Waiting for touch probe activation... "}

    ; Wait for a 100ms activation of the touch probe for a maximum of 30s
    M8002 K{global.mosTouchProbeID} D100 W30

    var touchProbeConnected = { exists(global.mosProbeDetected[global.mosTouchProbeID]) ? global.mosProbeDetected[global.mosTouchProbeID] : false }

    if { !var.touchProbeConnected }
        abort {"Did not detect touch probe with ID " ^ global.mosTouchProbeID ^ "! Please check your touch probe and run <b>T" ^ global.mosTouchProbeToolID ^ "</b> again to verify it is connected."}

    ; Return, touch probe is now active.
    M99
else

    if { global.mosTouchProbeToolID != null && global.mosToolSetterActivationPos == null }
        abort { "Touch probe feature is enabled but reference surface has not been probed. Please run <b>G6511</b> before probing tool lengths!" }

    ; All other tools cannot be detected so we just have to
    ; trust the operator did the right thing given the
    ; information :)
    if { !global.mosExpertMode }
        var toolLengthProbeMethod = { (global.featureToolSetter) ? "your Toolsetter." : "a Guided Manual probing procedure." }
        M291 P{"A tool change is required. You will be asked to insert the correct tool, and then the tool length will be probed using " ^ var.toolLengthProbeMethod} R"MillenniumOS: Tool Change" S2 T0

    ; Prompt user to change tool
    M291 P{"Insert Tool <b>#" ^ var.tI ^ "</b>: " ^ var.tD ^ " and press <b>Continue</b> when ready. <b>Cancel</b> will abort the running job!"} R"MillenniumOS: Tool Change" S4 K{"Continue", "Cancel"}
    if { input != 0 }
        abort { "Tool change aborted by operator, aborting job!" }

