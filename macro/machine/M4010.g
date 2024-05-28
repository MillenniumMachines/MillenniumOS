; M4010.g: RESET WCS PROBE DETAILS

if { !exists(param.W) || param.W < 0 || param.W > limits.workplaces }
    abort { "Invalid WCS - must be between 0 and " ^ limits.workplaces }

var wpNum = { param.W }

; Center, Corner, Circular, Surface, Dimensions, Rotation
; 1 2 4 8 16 32

; By default, reset everything
var reset = { exists(param.R) ? param.R : 63 }

if { !global.mosEM }
    echo { "Resetting WCS " ^ var.wpNum }

; If first bit is set, reset center position
; If second bit is set, reset corner position
; If third bit is set, reset circular position
; If fourth bit is set, reset surface position
; If fifth bit is set, reset dimensions
; If sixth bit is set, reset rotation

if { mod(floor(var.reset/pow(2,0)),2) == 1 }
    ; Reset Center
    echo { "Resetting WCS " ^ var.wpNum ^ " probed center"}
    set global.mosWPCtrPos[var.wpNum] = global.mosDfltWPCtrPos

if { mod(floor(var.reset/pow(2,1)),2) == 1 }
    ; Reset Corner
    echo { "Resetting WCS " ^ var.wpNum ^ " probed corner"}
    set global.mosWPCnrPos[var.wpNum] = global.mosDfltWPCnrPos
    set global.mosWPCnrDeg[var.wpNum] = global.mosDfltWPCnrDeg
    set global.mosWPCnrNum[var.wpNum] = global.mosDfltWPCnrNum

if { mod(floor(var.reset/pow(2,2)),2) == 1}
    ; Reset Circular
    echo { "Resetting WCS " ^ var.wpNum ^ " probed circular"}
    set global.mosWPRad[var.wpNum] = global.mosDfltWPRad

if { mod(floor(var.reset/pow(2,3)),2) == 1 }
    ; Reset Surface
    echo { "Resetting WCS " ^ var.wpNum ^ " probed surface"}
    set global.mosWPSfcAxis[var.wpNum] = global.mosDfltWPSfcAxis
    set global.mosWPSfcPos[var.wpNum] = global.mosDfltWPSfcPos

if { mod(floor(var.reset/pow(2,4)),2) == 1 }
    ; Reset Dimensions
    echo { "Resetting WCS " ^ var.wpNum ^ " probed dimensions"}
    set global.mosWPDims[var.wpNum] = global.mosDfltWPDims
    set global.mosWPDimsErr[var.wpNum] = global.mosDfltWPDimsErr

if { mod(floor(var.reset/pow(2,5)),2) == 1 }
    ; Reset Rotation
    echo { "Resetting WCS " ^ var.wpNum ^ " probed rotation"}
    set global.mosWPDeg[var.wpNum] = global.mosDfltWPDeg