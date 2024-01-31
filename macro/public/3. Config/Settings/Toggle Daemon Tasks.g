; MOS Toggle Daemon Tasks.g

; Toggles global.mosDaemonEnable so that daemon tasks
; can be controlled via DWC.
if { ! global.mosExpertMode }
    M291 R"MillenniumOS: Toggle Daemon Tasks" P{ (global.mosDaemonEnable  ? "Disable" : "Enable" ) ^ " Daemon tasks?" } S3
    if result == -1
        M99

set global.mosDaemonEnable = {!global.mosDaemonEnable}

echo {"MillenniumOS: Daemon tasks " ^ (global.mosDaemonEnable ? "Enabled" : "Disabled")}