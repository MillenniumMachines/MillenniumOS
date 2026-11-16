; G100.g - FACE MACRO
;
; Face the top of a previously probed part using the
; currently active tool.

; Get details about the current workpiece

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

; Default bounding box is empty
var boundingBox = { {0,0}, {0,0}, {0,0}, {0,0} }

var hasCentre     = { global.mosWPCtrPos[var.workOffset][0] != global.mosDfltWPCtrPos[0] && global.mosWPCtrPos[var.workOffset][1] != global.mosDfltWPCtrPos[1] }
var hasCorner     = { global.mosWPCnrPos[var.workOffset][0] != global.mosDfltWPCnrPos[0] && global.mosWPCnrPos[var.workOffset][1] != global.mosDfltWPCnrPos[1]  && global.mosWPCnrNum[var.workOffset] != global.mosDfltWPCnrNum }
var hasRadius     = { global.mosWPRad[var.workOffset] != global.mosDfltWPRad }
var hasDimensions = { global.mosWPDims[var.workOffset][0] != global.mosDfltWPDims[0] && global.mosWPDims[var.workOffset][1] != global.mosDfltWPDims[1] }

if { var.hasCentre && var.hasDimensions }
    ; Given the centre position and dimensions,
    ; calculate the bounding box of the workpiece.
    set var.boundingBox[0] = { global.mosWPCtrPos[var.workOffset][0] - global.mosWPDims[var.workOffset][0]/2, global.mosWPCtrPos[var.workOffset][1] - global.mosWPDims[var.workOffset][1]/2 }
    set var.boundingBox[1] = { global.mosWPCtrPos[var.workOffset][0] + global.mosWPDims[var.workOffset][0]/2, global.mosWPCtrPos[var.workOffset][1] + global.mosWPDims[var.workOffset][1]/2 }
    set var.boundingBox[2] = { global.mosWPCtrPos[var.workOffset][0] - global.mosWPDims[var.workOffset][0]/2, global.mosWPCtrPos[var.workOffset][1] + global.mosWPDims[var.workOffset][1]/2 }
    set var.boundingBox[3] = { global.mosWPCtrPos[var.workOffset][0] + global.mosWPDims[var.workOffset][0]/2, global.mosWPCtrPos[var.workOffset][1] - global.mosWPDims[var.workOffset][1]/2 }

elif { var.hasCorner && var.hasDimensions }
    ; Given the corner position and dimensions,
    ; calculate the bounding box of the workpiece
    ; based on the corner number.
    var cornerNum = { global.mosWPCnrNum[var.workOffset] }

    ; Calculate the bounding box based on the corner position
    if { var.cornerNum == 0 }
        set var.boundingBox[0] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
        set var.boundingBox[1] = { global.mosWPCnrPos[var.workOffset][0] + global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] + global.mosWPDims[var.workOffset][1] }
        set var.boundingBox[2] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] + global.mosWPDims[var.workOffset][1] }
        set var.boundingBox[3] = { global.mosWPCnrPos[var.workOffset][0] + global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
    elif { var.cornerNum == 1 }
        set var.boundingBox[0] = { global.mosWPCnrPos[var.workOffset][0] - global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
        set var.boundingBox[1] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] + global.mosWPDims[var.workOffset][1] }
        set var.boundingBox[2] = { global.mosWPCnrPos[var.workOffset][0] - global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] + global.mosWPDims[var.workOffset][1] }
        set var.boundingBox[3] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
    elif { var.cornerNum == 2 }
        set var.boundingBox[0] = { global.mosWPCnrPos[var.workOffset][0] - global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] - global.mosWPDims[var.workOffset][1] }
        set var.boundingBox[1] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
        set var.boundingBox[2] = { global.mosWPCnrPos[var.workOffset][0] - global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
        set var.boundingBox[3] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] - global.mosWPDims[var.workOffset][1] }
    elif { var.cornerNum == 3 }
        set var.boundingBox[0] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] - global.mosWPDims[var.workOffset][1] }
        set var.boundingBox[1] = { global.mosWPCnrPos[var.workOffset][0] + global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
        set var.boundingBox[2] = { global.mosWPCnrPos[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] }
        set var.boundingBox[3] = { global.mosWPCnrPos[var.workOffset][0] + global.mosWPDims[var.workOffset][0], global.mosWPCnrPos[var.workOffset][1] - global.mosWPDims[var.workOffset][1] }

elif { var.hasRadius && var.hasCentre }
    ; Given the centre position and radius,
    ; calculate the bounding box of the workpiece.

    set var.boundingBox[0] = { global.mosWPCtrPos[var.workOffset][0] - global.mosWPRad[var.workOffset], global.mosWPCtrPos[var.workOffset][1] - global.mosWPRad[var.workOffset] }
    set var.boundingBox[1] = { global.mosWPCtrPos[var.workOffset][0] + global.mosWPRad[var.workOffset], global.mosWPCtrPos[var.workOffset][1] + global.mosWPRad[var.workOffset] }
    set var.boundingBox[2] = { global.mosWPCtrPos[var.workOffset][0] - global.mosWPRad[var.workOffset], global.mosWPCtrPos[var.workOffset][1] + global.mosWPRad[var.workOffset] }
    set var.boundingBox[3] = { global.mosWPCtrPos[var.workOffset][0] + global.mosWPRad[var.workOffset], global.mosWPCtrPos[var.workOffset][1] - global.mosWPRad[var.workOffset] }


var tR = { global.mosTTD[state.currentTool][0] }
