; MOS Toggle VSSC.g

; Toggles global.mosVsscOverrideEnabled so that VSSC behaviour can be overridden
; by the operator on the fly.
if { ! global.mosExpertMode }
    M291 R"Toggle VSSC" P{ (global.mosVsscOverrideEnabled  ? "Disable" : "Enable" ) ^ " VSSC?" } S3
    if result == -1
        M99

set global.mosVsscOverrideEnabled = {!global.mosVsscOverrideEnabled}

echo {"VSSC Status: " ^ (global.mosVsscOverrideEnabled ? "Enabled" : "Disabled")}