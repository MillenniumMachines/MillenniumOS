; MOS: Toggle Daemon Tasks.g

; Toggles global.daemonEnable so that daemon tasks
; can be controlled via DWC.
set global.daemonEnable = !global.daemonEnable

echo {"Daemon Status: " ^ global.daemonEnable}