; MOS Toggle Expert Mode.g

; Toggles global.mosDaemonEnable so that daemon tasks
; can be controlled via DWC.
if { ! global.mosExpertMode }
    M291 R"Toggle Expert Mode" P"Enable Expert Mode? You will no longer be prompted to confirm potentially dangerous actions, and will not see probing descriptions before they are executed!" S3
    if result == -1
        M99

set global.mosExpertMode = {!global.mosExpertMode}

echo {"Expert Mode: " ^ (global.mosExpertMode ? "Enabled" : "Disabled")}