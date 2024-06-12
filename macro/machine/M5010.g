; M5010.g: RESET WCS PROBE DETAILS

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Center, Corner, Radius, Surface, Dimensions, Rotation
; 1 2 4 8 16 32

; By default, reset everything
var reset = { exists(param.R) ? param.R : 63 }

; If first bit is set, reset center position
; If second bit is set, reset corner position
; If third bit is set, reset radius
; If fourth bit is set, reset surface position
; If fifth bit is set, reset dimensions
; If sixth bit is set, reset rotation

if { mod(floor(var.reset/pow(2,0)),2) == 1 }
    ; Reset Center
    if { global.mosTM }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed center"}
    set global.mosWPCtrPos[var.workOffset] = global.mosDfltWPCtrPos

if { mod(floor(var.reset/pow(2,1)),2) == 1 }
    ; Reset Corner
    if { global.mosTM }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed corner"}
    set global.mosWPCnrPos[var.workOffset] = global.mosDfltWPCnrPos
    set global.mosWPCnrDeg[var.workOffset] = global.mosDfltWPCnrDeg
    set global.mosWPCnrNum[var.workOffset] = global.mosDfltWPCnrNum

if { mod(floor(var.reset/pow(2,2)),2) == 1}
    ; Reset Radius
    if { global.mosTM }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed radius"}
    set global.mosWPRad[var.workOffset] = global.mosDfltWPRad

if { mod(floor(var.reset/pow(2,3)),2) == 1 }
    ; Reset Surface
    if { global.mosTM }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed surface"}
    set global.mosWPSfcAxis[var.workOffset] = global.mosDfltWPSfcAxis
    set global.mosWPSfcPos[var.workOffset] = global.mosDfltWPSfcPos

if { mod(floor(var.reset/pow(2,4)),2) == 1 }
    ; Reset Dimensions
    if { global.mosTM }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed dimensions"}
    set global.mosWPDims[var.workOffset] = global.mosDfltWPDims
    set global.mosWPDimsErr[var.workOffset] = global.mosDfltWPDimsErr

if { mod(floor(var.reset/pow(2,5)),2) == 1 }
    ; Reset Rotation
    if { global.mosTM }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed rotation"}
    set global.mosWPDeg[var.workOffset] = global.mosDfltWPDeg