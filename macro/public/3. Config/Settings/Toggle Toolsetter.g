; Toggle Toolsetter.g

; Toggles global.mosDaemonEnable so that daemon tasks
; can be controlled via DWC.
if { global.mosFeatureToolSetter }
    M291 R"MillenniumOS: Toggle Toolsetter" P"Disable Toolsetter? You will have to compensate for tool length manually." S3
    if { result == -1 }
        M99

set global.mosFeatureToolSetter = {!global.mosFeatureToolSetter}

echo {"MillenniumOS: Toolsetter " ^ (global.mosFeatureToolSetter ? "Enabled" : "Disabled")}