; Toggle Expert Mode.g

if { global.mosTutorialMode }
    M291 R"MillenniumOS: Toggle Expert Mode" P"Enable Expert Mode? You will no longer be prompted to confirm potentially dangerous actions, and will not see probing descriptions before they are executed!" S3
    if { result == -1 }
        M99

set global.mosExpertMode = {!global.mosExpertMode}

echo {"MillenniumOS: Expert Mode " ^ (global.mosExpertMode ? "Enabled" : "Disabled")}