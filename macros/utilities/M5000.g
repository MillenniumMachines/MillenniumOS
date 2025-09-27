; M5000.g: GET TOOL-COMPENSATED ABSOLUTE POSITION
;
; Calculates the current tool-compensated absolute machine position
; and stores it in the global.nxtAbsPos array.
;
; This macro accounts for the current tool's offsets.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

M400 ; Wait for all moves to complete before reading positions

; Ensure the global variable is initialized as a 4-element array (X,Y,Z,A)
if { #global.nxtAbsPos != 4 }
    global nxtAbsPos = vector(4, 0.0)

; Iterate through the first 4 axes (X, Y, Z, A)
while { iterations < 4 }
    var currentTool = {state.currentTool}
    if { var.currentTool >= 0 && var.currentTool < #tools && iterations < #tools[var.currentTool].offsets }
        ; If a valid tool is active, subtract its offset from the machine position
        set global.nxtAbsPos[iterations] = {move.axes[iterations].machinePosition - tools[var.currentTool].offsets[iterations]}
    else
        ; If no tool is active or offsets are not defined, use machine position directly
        set global.nxtAbsPos[iterations] = {move.axes[iterations].machinePosition}
