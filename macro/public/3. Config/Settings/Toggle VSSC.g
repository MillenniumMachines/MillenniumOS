; Toggle VSSC.g

; Toggles global.mosVsscOverrideEnabled so that VSSC behaviour can be overridden
; by the operator on the fly.
if { global.mosTutorialMode }
    M291 R"MillenniumOS: Toggle VSSC" P{ (global.mosVsscOverrideEnabled  ? "Disable" : "Enable" ) ^ " Variable Spindle Speed Control?" } S3
    if { result == -1 }
        M99

set global.mosVsscOverrideEnabled = {!global.mosVsscOverrideEnabled}

echo {"MillenniumOS: VSSC " ^ (global.mosVsscOverrideEnabled ? "Enabled" : "Disabled")}