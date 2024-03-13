; Toggle VSSC.g

; Toggles global.mosVSOE so that VSSC behaviour can be overridden
; by the operator on the fly.
if { global.mosTM }
    M291 R"MillenniumOS: Toggle VSSC Override" P{ (global.mosVSOE  ? "Disable" : "Enable" ) ^ " Variable Spindle Speed Control?" } S3
    if { result == -1 }
        M99

set global.mosVSOE = {!global.mosVSOE}

; If VSSC override is disabled but VSSC
; was enabled, reset the spindle speed
; to the last recorded speed.
if { !global.mosVSOE && global.mosVSEnabled }
    if { spindles[global.mosSID].state == "forward" }
        ; Set spindle RPM
        M568 F{ global.mosVSPS }

; Update adjustment time and RPM
set global.mosVSPT = 0
set global.mosVSPS = 0

echo {"MillenniumOS: VSSC Override " ^ (global.mosVSOE ? "Enabled" : "Disabled")}