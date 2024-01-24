; resume.g - RESUME CURRENT JOB

; Make sure spindle is parked in Z
G27 Z1

; Reload the last tool used
T R1

echo { "Current position is: X=" ^ move.axes[0].machinePosition ^ " Y=" ^ move.axes[1].machinePosition ^ " Z=" ^ move.axes[2].machinePosition }
; Move to X/Y position above stored co-ordinates
G53 G0 R1 X0 Y0
M400
echo { "New position is: X=" ^ move.axes[0].machinePosition ^ " Y=" ^ move.axes[1].machinePosition ^ " Z=" ^ move.axes[2].machinePosition }

; If a tool was selected before the pause, try to
; restore the spindle speed.
var toolRpm = tools[state.curentTool].spindleRpm
if { state.currentTool >= 0 && var.toolRpm > 0 }
    ; Restore spindle speed from before the pause
    ; TODO: What about spindle direction?
    M3.1 S{var.toolRpm}