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

; Make sure we're in the default motion system
M598

if { state.nextTool < 0 }
    abort {"No tool selected!"}

if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    abort {"Machine must be homed before executing a tool change."}

; Stop and park the spindle
G27 Z1

; Check if we're switching to a probe.
if { state.nextTool == global.mosProbeToolID }
    ; If touch probe is enabled, prompt the operator to install
    ; it and check for activation.
    if { global.mosFeatureTouchProbe }
        M291 P{"Please install your touch probe into the spindle and make sure it is connected.<br/>When ready, press <b>OK</b>, and then manually activate it until it is detected."} R"MillenniumOS: Probe Tool" S2 T0

        echo { "Waiting for touch probe activation... "}

        ; Wait for a 100ms activation of the touch probe for a maximum of 30s
        M8002 K{global.mosTouchProbeID} D100 W30

        ; Touch probe may now be active or not.
        ; We check the touch probe status in tpost, as checking
        ; it here cannot abort the tool change anyway.

    else
        ; If no touch probe enabled, ask user to install datum tool.
        M291 P{"Please install your datum tool into the spindle. When ready, press <b>OK</b>."} R"MillenniumOS: Probe Tool" S2 T0
        echo { "Touch probe feature disabled, manual probing will use an installed datum tool." }
    M99
else

    if { global.mosFeatureTouchProbe && global.mosToolSetterActivationPos == null }
        abort { "Touch probe feature is enabled but reference surface has not been probed. Please run <b>G6511</b> before probing tool lengths!" }

    ; All other tools cannot be detected so we just have to
    ; trust the operator did the right thing given the
    ; information :)
    if { global.mosTutorialMode }
        M291 P{"A tool change is required. You will be asked to insert the correct tool, and then the tool length will be probed."} R"MillenniumOS: Tool Change" S2 T0

    ; Prompt user to change tool
    M291 P{"Insert Tool <b>#" ^ state.nextTool ^ "</b>: " ^ tools[state.nextTool].name ^ " and press <b>Continue</b> when ready. <b>Cancel</b> will abort the running job!"} R"MillenniumOS: Tool Change" S4 K{"Continue", "Cancel"}
    if { input != 0 }
        echo { "Tool change aborted by operator, aborting job!" }
        M99

