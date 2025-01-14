; M7601.g: PRINT WORKPLACE DETAILS
;
; Outputs non-null details about the specified WCS.
; If the WCS has been probed, then various values
; will be set in the global variables. We print these
; in a human-readable format if expert mode is off, and
; we print the variables and their actual values if
; expert mode is on.


if { exists(param.W) && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset must be between 0 and " ^ limits.workplaces-1 ^ "!" }

var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

if { !global.mosEM }
    if { global.mosWPCtrPos[var.workOffset][0] != null || global.mosWPCtrPos[var.workOffset][1] != null}
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Center Position X=" ^ global.mosWPCtrPos[var.workOffset][0] ^ " Y=" ^ global.mosWPCtrPos[var.workOffset][1] }

    if { global.mosWPRad[var.workOffset] != null }
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Radius=" ^ global.mosWPRad[var.workOffset] }

    if { global.mosWPCnrNum[var.workOffset] != null }
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Number=" ^ global.mosWPCnrNum[var.workOffset] }
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Name=" ^ global.mosCornerNames[global.mosWPCnrNum[var.workOffset]] }

    if { global.mosWPCnrPos[var.workOffset][0] != null && global.mosWPCnrPos[var.workOffset][1] != null}
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Position X=" ^ global.mosWPCnrPos[var.workOffset][0] ^ " Y=" ^ global.mosWPCnrPos[var.workOffset][1] }

    if { global.mosWPCnrDeg[var.workOffset] != null }
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Degrees=" ^ global.mosWPCnrDeg[var.workOffset] }

    if { global.mosWPDims[var.workOffset][0] != null || global.mosWPDims[var.workOffset][1] != null}
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Width=" ^ global.mosWPDims[var.workOffset][0] ^ " Length=" ^ global.mosWPDims[var.workOffset][1] }

    if { global.mosWPDimsErr[var.workOffset][0] != null || global.mosWPDimsErr[var.workOffset][1] != null}
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Width Error=" ^ global.mosWPDimsErr[var.workOffset][0] ^ " Length Error=" ^ global.mosWPDimsErr[var.workOffset][1] }

    if { global.mosWPDeg[var.workOffset] != null }
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Rotation Degrees=" ^ global.mosWPDeg[var.workOffset] }

    if { global.mosWPSfcAxis[var.workOffset] != null }
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Surface Axis=" ^ global.mosWPSfcAxis[var.workOffset] }

    if { global.mosWPSfcPos[var.workOffset] != null }
        echo {"WCS " ^ var.wcsNumber ^ " - Probed Surface Position=" ^ global.mosWPSfcPos[var.workOffset] }
else
    if { global.mosWPCtrPos[var.workOffset][0] != null || global.mosWPCtrPos[var.workOffset][1] != null}
        echo { "global.mosWPCtrPos[" ^ var.workOffset ^ "]=" ^ global.mosWPCtrPos[var.workOffset] }

    if { global.mosWPRad[var.workOffset] != null }
        echo { "global.mosWPRad[" ^ var.workOffset ^ "]=" ^ global.mosWPRad[var.workOffset]}

    if { global.mosWPCnrNum[var.workOffset] != null }
        echo { "global.mosWPCnrNum[" ^ var.workOffset ^ "]=" ^ global.mosWPCnrNum[var.workOffset] }

    if { global.mosWPCnrPos[var.workOffset][0] != null && global.mosWPCnrPos[var.workOffset][1] != null}
        echo { "global.mosWPCnrPos[" ^ var.workOffset ^ "]=" ^ global.mosWPCnrPos[var.workOffset] }

    if { global.mosWPCnrDeg[var.workOffset] != null }
        echo { "global.mosWPCnrDeg[" ^ var.workOffset ^ "]=" ^ global.mosWPCnrDeg[var.workOffset] }

    if { global.mosWPDims[var.workOffset][0] != null || global.mosWPDims[var.workOffset][1] != null}
        echo { "global.mosWPDims[" ^ var.workOffset ^ "]=" ^ global.mosWPDims[var.workOffset] }

    if { global.mosWPDimsErr[var.workOffset][0] != null || global.mosWPDimsErr[var.workOffset][1] != null}
        echo { "global.mosWPDimsErr[" ^ var.workOffset ^ "]=" ^ global.mosWPDimsErr[var.workOffset] }

    if { global.mosWPDeg[var.workOffset] != null }
        echo { "global.mosWPDeg[" ^ var.workOffset ^ "]=" ^ global.mosWPDeg[var.workOffset] }

    if { global.mosWPSfcAxis[var.workOffset] != null }
        echo { "global.mosWPSfcAxis[" ^ var.workOffset ^ "]=" ^ global.mosWPSfcAxis[var.workOffset] }

    if { global.mosWPSfcPos[var.workOffset] != null }
        echo { "global.mosWPSfcPos[" ^ var.workOffset ^ "]=" ^ global.mosWPSfcPos[var.workOffset] }
