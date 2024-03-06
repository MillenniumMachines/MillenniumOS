; Toggle VSSC.g

; Toggles global.mosVSOE so that VSSC behaviour can be overridden
; by the operator on the fly.
if { global.mosTM }
    M291 R"MillenniumOS: Toggle VSSC" P{ (global.mosVSOE  ? "Disable" : "Enable" ) ^ " Variable Spindle Speed Control?" } S3
    if { result == -1 }
        M99

set global.mosVSOE = {!global.mosVSOE}

echo {"MillenniumOS: VSSC " ^ (global.mosVSOE ? "Enabled" : "Disabled")}