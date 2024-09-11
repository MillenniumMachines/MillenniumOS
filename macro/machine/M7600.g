; M7600.g: PRINT ALL VARIABLES
;
; Outputs all MillenniumOS variables to the console.
; These variables can be useful where you are trying to do
; something non-standard with the probing macros.
; For example: we store the co-ordinates of the last probed
; corner for inside and outside probing macros including
; the index of the corner that was probed. You can
; use these variables in your own macro calls to implement custom
; functionality.

echo { "=== MOS Info:" }
echo { "      global.mosVer=" ^ global.mosVer }
echo { "      global.mosErr=" ^ global.mosErr }
echo { "      global.mosLdd=" ^ global.mosLdd }

echo { "=== MOS Features:" }
echo { "      global.mosFeatToolSetter=" ^ global.mosFeatToolSetter }
echo { "      global.mosFeatTouchProbe=" ^ global.mosFeatTouchProbe }
echo { "      global.mosFeatSpindleFeedback=" ^ global.mosFeatSpindleFeedback }
echo { "      global.mosFeatVSSC=" ^ global.mosFeatVSSC }

echo { "=== MOS Probing:" }
echo { "      global.mosPTID=" ^ global.mosPTID }
echo { "      global.mosPD=" ^ global.mosPD }
echo { "      global.mosDPID=" ^ global.mosDPID }
echo { "      global.mosOT=" ^ global.mosOT }
echo { "      global.mosCL=" ^ global.mosCL }
echo { "      global.mosWPCtrPos=" ^ global.mosWPCtrPos }
echo { "      global.mosWPDims=" ^ global.mosWPDims }
echo { "      global.mosWPRad=" ^ global.mosWPRad }
echo { "      global.mosWPDeg=" ^ global.mosWPDeg }
echo { "      global.mosWPCnrNum=" ^ global.mosWPCnrNum }
echo { "      global.mosWPCnrPos=" ^ global.mosWPCnrPos }
echo { "      global.mosWPCnrDeg=" ^ global.mosWPCnrDeg }
echo { "      global.mosWPSfcAxis=" ^ global.mosWPSfcAxis }
echo { "      global.mosWPSfcPos=" ^ global.mosWPSfcPos }

echo { "=== MOS Touch Probe:" }
echo { "      global.mosTPID=" ^ global.mosTPID }
echo { "      global.mosTPR=" ^ global.mosTPR }
echo { "      global.mosTPD=" ^ global.mosTPD }
echo { "      global.mosTPRP=" ^ global.mosTPRP }

echo { "=== MOS Toolsetter:" }
echo { "      global.mosTSID=" ^ global.mosTSID }
echo { "      global.mosTSP=" ^ global.mosTSP }
echo { "      global.mosTSAP=" ^ global.mosTSAP }

echo { "=== MOS Misc:" }
echo { "      global.mosPMBO=" ^ global.mosPMBO }

echo { "=== MOS Spindle:"}
echo { "      global.mosSID=" ^ global.mosSID }
echo { "      global.mosSAS=" ^ global.mosSAS }
echo { "      global.mosSDS=" ^ global.mosSDS }

if { exists(param.D) && param.D == 1 }
    echo "=== Additional Output from RRF for debugging purposes"
    M409 K"limits"
    M409 K"move"
    M409 K"sensors"
    M409 K"spindles"
    M409 K"state"
    M409 K"tools"
    echo "==="