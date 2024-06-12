; M7601.g: PRINT WORKPLACE DETAILS
;
; Outputs non-null details about the specified WCS.
; If the WCS has been probed, then various values
; will be set in the global variables. We print these
; in a human-readable format if expert mode is off, and
; we print the variables and their actual values if
; expert mode is on.


if { !exists(param.W) || param.W < 0 || param.W > limits.workplaces }
    abort { "Invalid WCS - must be between 0 and " ^ limits.workplaces }

var wpNum = { param.W }

if { !global.mosEM }
    if { global.mosWPCtrPos[var.wpNum][0] != null && global.mosWPCtrPos[var.wpNum][1] != null}
        echo {"WCS " ^ var.wpNum ^ " - Probed Center Position X=" ^ global.mosWPCtrPos[var.wpNum][0] ^ " Y=" ^ global.mosWPCtrPos[var.wpNum][1] }

    if { global.mosWPRad[var.wpNum] != null }
        echo {"WCS " ^ var.wpNum ^ " - Probed Radius=" ^ global.mosWPRad[var.wpNum] }

    if { global.mosWPCnrNum[var.wpNum] != null }
        echo {"WCS " ^ var.wpNum ^ " - Probed Corner Number=" ^ global.mosWPCnrNum[var.wpNum] }
        echo {"WCS " ^ var.wpNum ^ " - Probed Corner Name=" ^ global.mosCnr[global.mosWPCnrNum[var.wpNum]] }

    if { global.mosWPCnrPos[var.wpNum][0] != null && global.mosWPCnrPos[var.wpNum][1] != null}
        echo {"WCS " ^ var.wpNum ^ " - Probed Corner Position X=" ^ global.mosWPCnrPos[var.wpNum][0] ^ " Y=" ^ global.mosWPCnrPos[var.wpNum][1] }

    if { global.mosWPCnrDeg[var.wpNum] != null }
        echo {"WCS " ^ var.wpNum ^ " - Probed Corner Degrees=" ^ global.mosWPCnrDeg[var.wpNum] }

    if { global.mosWPDims[var.wpNum][0] != null && global.mosWPDims[var.wpNum][1] != null}
        echo {"WCS " ^ var.wpNum ^ " - Probed Width=" ^ global.mosWPDims[var.wpNum][0] ^ " Length=" ^ global.mosWPDims[var.wpNum][1] }

    if { global.mosWPDimsErr[var.wpNum][0] != null && global.mosWPDimsErr[var.wpNum][1] != null}
        echo {"WCS " ^ var.wpNum ^ " - Probed Width Error=" ^ global.mosWPDimsErr[var.wpNum][0] ^ " Length Error=" ^ global.mosWPDimsErr[var.wpNum][1] }

    if { global.mosWPDeg[var.wpNum] != null }
        echo {"WCS " ^ var.wpNum ^ " - Probed Rotation Degrees=" ^ global.mosWPDeg[var.wpNum] }

    if { global.mosWPSfcAxis[var.wpNum] != null }
        echo {"WCS " ^ var.wpNum ^ " - Probed Surface Axis=" ^ global.mosWPSfcAxis[var.wpNum] }

    if { global.mosWPSfcPos[var.wpNum] != null }
        echo {"WCS " ^ var.wpNum ^ " - Probed Surface Position=" ^ global.mosWPSfcPos[var.wpNum] }
else
    if { global.mosWPCtrPos[var.wpNum][0] != null && global.mosWPCtrPos[var.wpNum][1] != null}
        echo { "global.mosWPCtrPos[" ^ var.wpNum ^ "]=" ^ global.mosWPCtrPos[var.wpNum] }

    if { global.mosWPRad[var.wpNum] != null }
        echo { "global.mosWPRad[" ^ var.wpNum ^ "]=" ^ global.mosWPRad[var.wpNum]}

    if { global.mosWPCnrNum[var.wpNum] != null }
        echo { "global.mosWPCnrNum[" ^ var.wpNum ^ "]=" ^ global.mosWPCnrNum[var.wpNum] }

    if { global.mosWPCnrPos[var.wpNum][0] != null && global.mosWPCnrPos[var.wpNum][1] != null}
        echo { "global.mosWPCnrPos[" ^ var.wpNum ^ "]=" ^ global.mosWPCnrPos[var.wpNum] }

    if { global.mosWPCnrDeg[var.wpNum] != null }
        echo { "global.mosWPCnrDeg[" ^ var.wpNum ^ "]=" ^ global.mosWPCnrDeg[var.wpNum] }

    if { global.mosWPDims[var.wpNum][0] != null && global.mosWPDims[var.wpNum][1] != null}
        echo { "global.mosWPDims[" ^ var.wpNum ^ "]=" ^ global.mosWPDims[var.wpNum] }

    if { global.mosWPDimsErr[var.wpNum][0] != null && global.mosWPDimsErr[var.wpNum][1] != null}
        echo { "global.mosWPDimsErr[" ^ var.wpNum ^ "]=" ^ global.mosWPDimsErr[var.wpNum] }

    if { global.mosWPDeg[var.wpNum] != null }
        echo { "global.mosWPDeg[" ^ var.wpNum ^ "]=" ^ global.mosWPDeg[var.wpNum] }

    if { global.mosWPSfcAxis[var.wpNum] != null }
        echo { "global.mosWPSfcAxis[" ^ var.wpNum ^ "]=" ^ global.mosWPSfcAxis[var.wpNum] }

    if { global.mosWPSfcPos[var.wpNum] != null }
        echo { "global.mosWPSfcPos[" ^ var.wpNum ^ "]=" ^ global.mosWPSfcPos[var.wpNum] }