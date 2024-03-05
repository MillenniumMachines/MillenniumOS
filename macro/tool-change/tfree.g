; tfree.g: FREE CURRENT TOOL
; If the current tool is a touch probe, then
; prompt the operator to remove it from the spindle
; and stow it safely before proceeding.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Make sure we're in the default motion system
M598

if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    abort {"Machine must be homed before executing a tool change."}

; Stop and park the spindle
G27 Z1

; If probe tool is selected
if { state.currentTool == global.mosProbeToolID }
    if { global.mosFeatureTouchProbe }
        M291 P{"Please remove the touch probe now and stow it safely away from the machine. Click <b>OK</b> when stowed safely."} R{"MillenniumOS: Touch Probe"} S2
    else
        M291 P{"Please remove the datum tool now and stow it safely away from the machine. Click <b>OK</b> when stowed safely."} R{"MillenniumOS: Datum Tool"} S2