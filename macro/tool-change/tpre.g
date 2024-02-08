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

if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    abort {"Machine must be homed before executing a tool change."}
    T-1 P0
    M99

; Stop and park the spindle
G27 Z1

var tD = {(exists(tools[var.tI])) ? tools[var.tI].name : "Unknown Tool" }

; Check if we're switching to a probe.
if { var.tI == global.mosProbeToolID }
    ; If touch probe is enabled, prompt the operator to install
    ; it and check for activation.
    if { global.mosFeatureTouchProbe }
        M291 P{"Please install your " ^ var.tD ^ " into the spindle and make sure it is connected.<br/>When ready, press <b>OK</b>, and then manually activate your " ^ var.tD ^ " until it is detected."} R"MillenniumOS: Probe Tool" S2 T0

        echo { "Waiting for touch probe activation... "}

        ; Wait for a 100ms activation of the touch probe for a maximum of 30s
        M8002 K{global.mosTouchProbeID} D100 W30

        ; Check if requested probe ID was detected.
        var touchProbeConnected = { exists(global.mosProbeDetected[global.mosTouchProbeID]) ? global.mosProbeDetected[global.mosTouchProbeID] : false }

        if { !var.touchProbeConnected }
            echo {"Did not detect a " ^ var.tD ^ " with ID " ^ global.mosTouchProbeID ^ "! Please check your " ^ var.tD ^ " and run <b>T" ^ global.mosProbeToolID ^ "</b> again to verify it is connected."}
            M99
        ; Touch probe is now active.

    else
        ; If no touch probe enabled, ask user to install datum tool.
        M291 P{"Please install your " ^ var.tD ^ " into the spindle. When ready, press <b>OK</b>."} R"MillenniumOS: Probe Tool" S2 T0
        echo { "Touch probe feature disabled, manual probing will use an installed datum tool." }
    M99
else

    if { global.mosFeatureTouchProbe && global.mosToolSetterActivationPos == null }
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
        echo { "Tool change aborted by operator, aborting job!" }
        M99

