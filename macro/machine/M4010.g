; M4010.g: RESET WCS PROBE DETAILS

if { !exists(param.W) || param.W < 0 || param.W > limits.workplaces }
    abort { "Invalid WCS - must be between 0 and " ^ limits.workplaces }

var wpNum = { param.W }

; Center, Corner, Circular, Surface, Dimensions, Rotation
; 1 2 4 8 16 32

var reset = { exists(param.R) ? param.R : 0 }

if { !global.mosEM }
    echo { "Resetting WCS " ^ var.wpNum ^ " probed details"}

; Reset Center if bit 1 is set
if { mod(var.reset, 2) == 1 }
    ; Reset Center
    set global.mosWPCtrPos[var.wpNum] = global.mosDfltWPCtrPos

if { (mod(var.reset, 4) / 2) == 1 }
    ; Reset Corner
    set global.mosWPCnrPos[var.wpNum] = global.mosDfltWPCnrPos
    set global.mosWPCnrDeg[var.wpNum] = global.mosDfltWPCnrDeg
    set global.mosWPCnrNum[var.wpNum] = global.mosDfltWPCnrNum

if { (mod(var.reset, 8) / 4) == 1 }
    ; Reset Circular
    set global.mosWPRad[var.wpNum] = global.mosDfltWPRad

if { (mod(var.reset, 16) / 8) == 1 }
    ; Reset Surface
    set global.mosWPSfcAxis[var.wpNum] = global.mosDfltWPSfcAxis
    set global.mosWPSfcPos[var.wpNum] = global.mosDfltWPSfcPos

if { (mod(var.reset, 32) / 16) == 1 }
    ; Reset Dimensions
    set global.mosWPDims[var.wpNum] = global.mosDfltWPDims
    set global.mosWPDimsError[var.wpNum] = global.mosDfltWPDimsError

if { (var.reset / 32) == 1 }
    ; Reset Rotation
    set global.mosWPDeg[var.wpNum] = global.mosDfltWPDeg

