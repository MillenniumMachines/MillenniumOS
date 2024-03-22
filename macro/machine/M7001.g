; M7001.g: DISABLE VSSC
;
; Disable Variable Spindle Speed Control
;
; USAGE: "M7001"

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Disable the daemon process
set global.mosVSEnabled  = false

; If spindle is active, adjust speed to last recorded
; 'base' RPM
if { spindles[global.mosSID].state == "forward" }
    ; Set spindle RPM
    M568 F{ global.mosVSPS }

    if { global.mosDebug }
        echo {"[VSSC]: State: Disabled RPM: " ^ global.mosVSPS }
else
    if { global.mosDebug }
        echo {"[VSSC]: State: Disabled" }

; Update adjustment time, RPM and direction
set global.mosVSPT = 0
set global.mosVSPS = 0