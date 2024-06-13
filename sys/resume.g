; resume.g - RESUME CURRENT JOB

; Make sure spindle is parked in Z
G27 Z1

; Reload the last tool used
T R1

; If a tool was selected before the pause, try to
; restore the spindle speed.
if { state.currentTool >= 0 && state.currentTool < limits.tools}
    if { tools[state.currentTool].spindleRpm > 0 }
        ; Restore spindle speed from before the pause
        ; TODO: What about spindle direction?

        ; Stop spindle and wait
        M98 P"M3.9.g" S{ tools[state.currentTool].spindleRpm }

; Move to X/Y position above the stored co-ordinates
; This will occur at machine Z=0 as we parked the
; spindle above.
G53 G0 R1 X0 Y0

; Enable coolants if they were enabled before pausing
M9 R1

; Move down to the stored co-ordinates.
G53 G0 R1 X0 Y0 Z0