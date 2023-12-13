; daemon.g
;
; MillenniumOS Daemon framework.
;
; If you want to add your own scheduled tasks, add them as an M98 macro call under the
; MillenniumOS ones below. Make sure they are indented inside the daemonEnable loop,
; otherwise it will be impossible to control misbehaving daemon tasks from DWC.

if { !exists(global.mosLoaded) || !global.mosLoaded }
    echo "MillenniumOS not loaded!"
    M99

while global.daemonEnable
    G4 P{global.daemonUpdateRate} ; Minimum interval between daemon runs

    ; Only run VSSC when feature is enabled and VSSC has been activated
    if { exists(global.featureVSSC) && global.featureVSSC == true && global.vsscEnabled }
        M98 P"macro/daemon/mos-run-vssc.g" ; Update active spindle speed based on timings