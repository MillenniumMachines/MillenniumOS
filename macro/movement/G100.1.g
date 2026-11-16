; G100.g - FACE MACRO - RECTANGULAR
;
; Use a linear toolpath to face the top of
; a part, using the currently active tool.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

; Get radius of current tool
var tR = { global.mosTTD[state.currentTool][0] }

; Calculate tool paths based on bounding box and tool radius to ensure
; the entire workpiece surface is machined.
var tX = { var.boundingBox[0][0] - var.tR }
var tY = { var.boundingBox[0][1] - var.tR }
var tZ = { global.mosWPCtrPos[var.workOffset][2] }
var rZ = { var.tZ + 10 }
var tW = { var.boundingBox[1][0] + var.tR }
var tH = { var.boundingBox[1][1] + var.tR }

; Set the horizontal feed rate to the default feedrate if not specified
var feedrateH = { (exists(param.F) && param.F != null) ? param.F : 1000 }

; Set the vertical feed rate to the default feed rate if not specified
var feedrateV = { (exists(param.P) && param.P != null) ? param.P : 1000 }

; Move to the rapid height over the starting position
G0 X{var.tX} Y{var.tY} Z{var.rZ}

; Feed down to the surface at the vertical feed rate
G1 Z{var.tZ} F{var.feedrateV}

; While we have not covered the entire bounding box
while { var.tY < var.tH }
    ; Move to the right side of the bounding box
    G1 X{var.tW} F{var.feedrateH}

    ; Move to the left side of the bounding box
    G1 X{var.tX} F{var.feedrateH}

    ; Move up to the next row
    set var.tY = { var.tY + 2 * var.tR }
    G1 Y{var.tY} F{var.feedrateH}

    ; Move down to the next row
    G1 Y{var.tY} F{var.feedrateH}




