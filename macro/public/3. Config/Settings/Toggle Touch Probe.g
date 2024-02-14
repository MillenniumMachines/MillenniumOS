; Toggle Touch Probe.g

if { global.mosFeatureTouchProbe }
    M291 R"MillenniumOS: Toggle Touch Probe" P"Disable Touch Probe? This will enable guided manual workpiece probing." S3
    if { result == -1 }
        M99

; These 3 values are required for touch probe use.
if { global.mosTouchProbeID == null || global.mosTouchProbeReferencePos == null || global.mosTouchProbeRadius == null || global.mosTouchProbeDeflection == null }
    M291 R"MillenniumOS: Toggle Touch Probe" P"Touch Probe has not been configured. Please configure the touch probe using the Configuration Wizard first." S2
    M99

set global.mosFeatureTouchProbe = {!global.mosFeatureTouchProbe}

; Switch probe tool name and configuration when toggling touch probe
if { global.mosFeatureTouchProbe }
    M4001 P{global.mosProbeToolID}
    M4000 P{global.mosProbeToolID} S{global.mosTouchProbeToolName} R{global.mosTouchProbeRadius}
else
    M4001 P{global.mosProbeToolID}
    M4000 P{global.mosProbeToolID} S{global.mosDatumToolName} R{global.mosDatumToolRadius}

echo {"MillenniumOS: Touch Probe " ^ (global.mosFeatureTouchProbe ? "Enabled" : "Disabled")}