; daemon.g
;
; MillenniumOS Daemon framework.
;

; Display any startup messages
M98 P"mos/display-startup-messages.g"

; If you want to add your own scheduled tasks, add them as an M98 macro call under the
; MillenniumOS ones below. Make sure they are indented inside the daemonEnable loop,
; otherwise it will be impossible to control misbehaving daemon tasks from DWC.
while { exists(global.mosDaemonEnable) && global.mosDaemonEnable }
    G4 P{global.mosDaemonUpdateRate} ; Minimum interval between daemon runs

    ; Only run VSSC when feature is enabled and VSSC has been activated
    if { exists(global.mosFeatureVSSC) && global.mosFeatureVSSC == true && global.mosVsscEnabled && global.mosVsscOverrideEnabled }
        M98 P"mos/run-vssc.g" ; Update active spindle speed based on timings
