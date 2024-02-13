; tfree.g: FREE CURRENT TOOL
; If the current tool is a touch probe, then
; prompt the operator to remove it from the spindle
; and stow it safely before proceeding.

if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    abort {"Machine must be homed before executing a tool change."}
    M99

; Stop and park the spindle
G27 Z1

var tI = { state.currentTool }

; If probe tool is selected
if { state.currentTool == global.mosProbeToolID }
    if { global.mosFeatureTouchProbe }
        M291 P{"Please remove the touch probe now and stow it safely away from the machine. Click <b>OK</b> when stowed safely."} R{"MillenniumOS: Touch Probe"} S2
    else
        M291 P{"Please remove the datum tool now and stow it safely away from the machine. Click <b>OK</b> when stowed safely."} R{"MillenniumOS: Datum Tool"} S2