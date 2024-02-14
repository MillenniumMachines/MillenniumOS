; Toggle Debug Mode.g

if { ! global.mosDebug }
    M291 R"MillenniumOS: Toggle Debug Mode" P"Enable Debug Mode? This will produce very verbose output to the console and may make it hard to find non-debug messages!" S3
    if { result == -1 }
        M99

set global.mosDebug = {!global.mosDebug}

echo {"MillenniumOS: Debug Mode " ^ (global.mosDebug ? "Enabled" : "Disabled")}