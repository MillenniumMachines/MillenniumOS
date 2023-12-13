; MOS: Toggle Expert Mode.g

; Toggles global.daemonEnable so that daemon tasks
; can be controlled via DWC.
set global.expertMode = !global.expertMode

echo {"Expert Mode: " ^ global.expertMode ? "Enabled" : "Disabled"}