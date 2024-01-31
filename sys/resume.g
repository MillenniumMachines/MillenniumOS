; resume.g - RESUME CURRENT JOB

; Make sure spindle is parked in Z
G27 Z1

; Reload the last tool used
T R1

; If a tool was selected before the pause, try to
; restore the spindle speed.
var toolRpm = tools[state.currentTool].spindleRpm
if { state.currentTool >= 0 && var.toolRpm > 0 }
    ; Restore spindle speed from before the pause
    ; TODO: What about spindle direction?
    M3.9 S{var.toolRpm}

; Move to X/Y position above stored co-ordinates
G53 G0 R1 X0 Y0 Z10

; Wait for move to complete.
M400