; M7001.g: DISABLE VSSC
;
; Disable Variable Spindle Speed Control
;
; USAGE: "M7001"

; Disable the daemon process
set global.mosVsscEnabled  = false

; If spindle is active, adjust speed to last recorded
; 'base' RPM
if { spindles[global.mosSpindleID].state == "forward" }
    ; Set spindle RPM
    M568 F{ global.mosVsscPreviousAdjustmentRPM }

    if { global.mosVsscDebug }
        echo {"[VSSC]: State: Disabled RPM: " ^ global.mosVsscPreviousAdjustmentRPM }
else
    if { global.mosVsscDebug }
        echo {"[VSSC]: State: Disabled" }

; Update adjustment time, RPM and direction
set global.mosVsscPreviousAdjustmentTime = 0
set global.mosVsscPreviousAdjustmentRPM  = 0
set global.mosVsscPreviousAdjustmentDir  = true