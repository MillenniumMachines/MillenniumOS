; G100.g - FACE MACRO - CIRCULAR
;
; Use a circular toolpath to face the top of
; a part, using the currently active tool.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

var extraOffset = { exists(param.E)? param.E : 0 }

var radius = { param.R }

var ctrPos = { param.P }

; Get radius of current tool
var tR = { global.mosTTD[state.currentTool][0] }

; Set the horizontal feed rate to the default feedrate if not specified
var feedrateH = { (exists(param.F) && param.F != null) ? param.F : 1000 }

; Set the vertical feed rate to the default feed rate if not specified
var feedrateV = { (exists(param.P) && param.P != null) ? param.P : 1000 }

; Get spindle direction
var spindleDir = { spindles[global.mosSID].current < 0 ? -1 : 1 }

; Set the stepover to 40% of the tool radius
var stepOver = 0.4

; Set the stepdown to 0.5mm
var stepDown = 0.5

; We want to use climb milling for the roughing pass
; and then conventional milling for the finishing pass.

; We calculate the start position based on the spindle direction, tool radius and extra offset

var tZ = { global.mosWPCtrPos[var.workOffset][2] }
var sZ = { var.tZ + 10 }
var nZ = { var.sZ }
var cR = { var.radius + var.extraOffset + var.tR }

; Move inwards by the stepover amount for each rotation around
; the center point.
var inPerHemisphere = { (var.stepOver * var.tR) / 2 }

; Arcs are in XY plane
G17

while { var.nZ > var.tZ }
    ; Reduce the Z position by the stepdown
    set var.nZ = { var.nZ - var.stepDown }

    ; Rapid to the start position in X and Y
    G0 X{var.ctrPos[0] + var.cR} Y{var.ctrPos[1]}

    ; Feed down to the new Z position
    G1 Z{var.nZ} F{var.feedrateV}

    ; While the current radius is larger than the tool radius
    while { var.cR > var.tR }
        ; Move inwards towards the radius, using 2 x 180 degree
        ; arcs. Each arc should move in by the inPerHemisphere
        ; amount.

        ; We should use conventional milling for the roughing, and then
        ; switch to climb milling for the finishing pass.
        if { var.spindleDir > 0 }
            G2 X{var.ctrPos[0] - var.cR + var.inPerHemisphere} Y{var.ctrPos[1]} I{var.inPerHemisphere} J{var.ctrPos[1]} F{var.feedrateH}
            G2 X{var.ctrPos[0] + var.cR - var.inPerHemisphere} Y{var.ctrPos[1]} I{-var.inPerHemisphere} J{var.ctrPos[1]} F{var.feedrateH}

        else
            G3 X{var.ctrPos[0] - var.cR + var.inPerHemisphere} Y{var.ctrPos[1]} I{var.inPerHemisphere} J{var.ctrPos[1]} F{var.feedrateH}
            G3 X{var.ctrPos[0] + var.cR - var.inPerHemisphere} Y{var.ctrPos[1]} I{-var.inPerHemisphere} J{var.ctrPos[1]} F{var.feedrateH}

        ; Reduce the current radius by 2 times the inPerHemisphere
        ; amount. Make sure we don't go below the tool radius.
        set var.cR = { max(var.cR - (2 * var.inPerHemisphere), var.tR) }

    ; Make the final fully circular path at the tool radius
    if { var.spindleDir > 0 }
        G2 X{var.ctrPos[0] - var.tR} Y{var.ctrPos[1]} I{var.tR} J0 F{var.feedrateH}
    else
        G3 X{var.ctrPos[0] - var.tR} Y{var.ctrPos[1]} I{var.tR} J0 F{var.feedrateH}

    G0 Z{var.nZ}
    set var.nZ = { max(var.nZ - var.stepDown, var.tZ) }
