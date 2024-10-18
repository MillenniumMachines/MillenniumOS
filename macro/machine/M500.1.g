; M500.1.g: Save restorable settings to config-override.g
;
; USAGE: M500.1
; RRF already supports the M500 command, but calling this
; will throw a warning if there was no matching M501 command
; in the configuration. This is a pain, because it means
; WCS origins and tools cannot be restored conditionally.

var restoreFile = { "config-override.g" }

var workOffsetCodes={"G54","G55","G56","G57","G58","G59","G59.1","G59.2","G59.3"}

echo >{var.restoreFile} { "; Restorable settings for WCS and tools" }

echo >>{var.restoreFile} { "; Restore WCS Origins" }
while { iterations < limits.workplaces }
    echo >>{var.restoreFile} {"G10 L2 P" ^ iterations+1 ^ " X" ^ move.axes[0].workplaceOffsets[iterations] ^ " Y" ^ move.axes[1].workplaceOffsets[iterations] ^ " Z" ^ move.axes[2].workplaceOffsets[iterations] }

; Save toolsetter activation point if touch probe is enabled
if { global.mosFeatTouchProbe }
    echo >>{var.restoreFile} { "; Restore Touch Probe Activation Point" }
    echo >>{var.restoreFile} { "set global.mosTSAP = " ^ global.mosTSAP }

if { state.currentTool != -1 }
    echo >>{var.restoreFile} { "; Restore Tool and Offset" }
    ; Save the current tool
    echo >>{var.restoreFile} { "M4000 P" ^ state.currentTool ^ " R" ^ global.mosTT[state.currentTool][0] ^ " S""" ^ tools[state.currentTool].name ^ """" }

    ; Switch to the current tool without triggering a tool change
    echo >>{var.restoreFile} { "T" ^ state.currentTool ^ " P0" }

    ; Set the tool offset
    echo >>{var.restoreFile} { "G10 L1 P" ^ state.currentTool ^ " Z" ^ tools[state.currentTool].offsets[2] }

echo >>{var.restoreFile} { "; Restore Current WCS" }
echo >>{var.restoreFile} { var.workOffsetCodes[move.workplaceNumber] }