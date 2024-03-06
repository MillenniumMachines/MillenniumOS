; Toggle Daemon Tasks.g

if { global.mosTM }
    M291 R"MillenniumOS: Toggle Daemon Tasks" P{ (global.mosDAE  ? "Disable" : "Enable" ) ^ " Daemon tasks?" } S3
    if result == -1
        M99

set global.mosDAE = {!global.mosDAE}

echo {"MillenniumOS: Daemon tasks " ^ (global.mosDAE ? "Enabled" : "Disabled")}