; daemon.g
;
; MillenniumOS Daemon framework.
;

; Display any startup messages
M98 P"mos/display-startup-messages.g"

; If you want to add your own scheduled tasks, create the user-daemon.g
; file in your /sys directory and add your tasks there. DO NOT use any
; infinite loops as we already loop in this file.
while { exists(global.mosDAE) && global.mosDAE }
    G4 P{global.mosDAEUR} ; Minimum interval between daemon runs

    ; Run the ArborCtl daemon if it exists
    if { fileexists("0:/sys/arborctl/arborctl-daemon.g") }
        M98 P"arborctl/arborctl-daemon.g"

    ; Only run VSSC when feature is enabled and VSSC has been activated
    if { exists(global.mosFeatVSSC) && global.mosFeatVSSC == true && global.mosVSEnabled && global.mosVSOE }
        M98 P"mos/run-vssc.g" ; Update active spindle speed based on timings

    if { fileexists("0:/sys/user-daemon.g") }
        M98 P"user-daemon.g"
