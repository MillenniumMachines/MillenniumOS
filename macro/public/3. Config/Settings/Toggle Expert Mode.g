; Toggle Expert Mode.g

if { global.mosTM }
    M291 R"MillenniumOS: Toggle Expert Mode" P"Enable Expert Mode? You will no longer be prompted to confirm potentially dangerous actions, and will not see probing descriptions before they are executed!" S3
    if { result == -1 }
        M99

set global.mosEM = {!global.mosEM}

echo {"MillenniumOS: Expert Mode " ^ (global.mosEM ? "Enabled" : "Disabled")}