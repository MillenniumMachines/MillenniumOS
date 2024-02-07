; Toggle Touch Probe.g

; Toggles global.mosDaemonEnable so that daemon tasks
; can be controlled via DWC.
if { global.mosFeatureTouchProbe }
    M291 R"MillenniumOS: Toggle Touch Probe" P"Disable Touch Probe? This will enable guided manual workpiece probing." S3
    if { result == -1 }
        M99

set global.mosFeatureTouchProbe = {!global.mosFeatureTouchProbe}

; Switch probe tool name and configuration when toggling touch probe
if { global.mosFeatureTouchProbe }
    M4001 P{global.mosProbeToolID}
    M4000 P{global.mosProbeToolID} S{global.mosTouchProbeToolName} R{global.mosTouchProbeRadius - global.mosTouchProbeDeflection}
else
    M4001 P{global.mosProbeToolID}
    M4000 P{global.mosProbeToolID} S{global.mosDatumToolName} R{global.mosDatumToolRadius}

echo {"MillenniumOS: Touch Probe " ^ (global.mosFeatureTouchProbe ? "Enabled" : "Disabled")}