; M6.g - TOOL CHANGE: EXECUTE
; Calledd to trigger a guided tool change.

; RRF's toolchange macros have to be pre-defined per-tool.
; This is a pain because it means we need to account for all tool
; numbers - but we do the same thing for every tool anyway, which
; is - stop the spindle, park it, and prompt the user to change
; the tool manually before proceeding.
; We rely on RRF tracking the currently active tool (set using T<N>)
; and when this macro is called, we prompt the user to switch to that
; tool with details from the RRF tool table.

; Stop and park the spindle
G27 Z1

var tI = { state.currentTool }

if { var.tI < 0 }
    M291 P{"No tool selected! Aborting tool change."} R"MillenniumOS: Tool Change" S3
    M25

var tD = {(exists(tools[var.tI])) ? tools[var.tI].name : "Unknown Tool" }

; Prompt user to change tool
M291 P{"Insert Tool #" ^ var.tI ^ ": " ^ var.tD ^ " and press Continue when ready. Cancel will abort the guided tool-change."} R"MillenniumOS: Tool Change" S4 K{"Continue", "Cancel"}
if { input != 0 }
    M25.1 S{ "Guided tool change aborted by operator. Job has been paused. You may continue by pressing Resume Job, but you will need to perform the tool change manually (dont forget to set the right offset)!" }
    M99

; Probe tool length offset with G37
G37

; Continue after user confirmation if necessary
if { !global.mosExpertMode }
    M291 P{"Tool change complete. Press Continue to start the next operation, or Pause to perform further manual tasks (e.g. workpiece fixture changes)"} R"MillenniumOS: Tool Change" S4 K{"Continue", "Pause"}
    if { input != 0 }
        M25.1 S{"Operator paused job after tool change complete." }