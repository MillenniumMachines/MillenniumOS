; mos-boot.g
;
; Load MillenniumOS.
; This involves sanity checking variables and aborting if they are not set.

; Confirm RRF is in CNC mode.
if { state.machineMode != "CNC" }
    set global.mosStartupError = { "Machine mode must be set to CNC using M453!" }
    M99

if { move.axes[2].max > 0 || move.axes[2].min >= 0 }
    set global.mosStartupError = { "Your Z axis uses positive co-ordinates which are untested and unsupported. Please configure your Z max as 0 and Z min as a negative number." }
    M99

; Remove existing probe tool so
; it can be redefined.
M4001 P{global.mosProbeToolID}

; If we have a touch probe, make sure the co-ordinates are set
if { global.mosFeatureTouchProbe }
    ; If we have a touch probe, make sure we have the ID set
    if { !exists(global.mosTouchProbeID) || global.mosTouchProbeID == null }
        set global.mosStartupError = { "<b>global.mosTouchProbeID</b> must contain the ID of the touch probe. Configure it using M558 K<probe-id>... in config.g, then run the configuration wizard (<b>G8000</b>)." }
        M99
    if { !exists(global.mosTouchProbeReferencePos) || global.mosTouchProbeReferencePos == null }
        set global.mosStartupError = { "<b>global.mosTouchProbeReferencePos</b> is not set. Run the configuration wizard to fix this (<b>G8000</b>)." }
        M99
    if { !exists(global.mosTouchProbeRadius) || global.mosTouchProbeRadius == null }
        set global.mosStartupError = { "<b>global.mosTouchProbeRadius</b> is not set. Run the configuration wizard to fix this (<b>G8000</b>)." }
        M99
    if { !exists(global.mosTouchProbeDeflection) || global.mosTouchProbeDeflection == null }
        set global.mosStartupError = { "<b>global.mosTouchProbeDeflection</b> is not set. Run the configuration wizard to fix this (<b>G8000</b>)." }
        M99

    ; Add a touch probe tool at the last index in the tool table.
    ; Make sure to specify deflection values for compensation.
    M4000 S{"Touch Probe"} P{global.mosProbeToolID} R{global.mosTouchProbeRadius} X{global.mosTouchProbeDeflection[0]} Y{global.mosTouchProbeDeflection[1]}
else
    if { !exists(global.mosDatumToolRadius) || global.mosDatumToolRadius == null }
        set global.mosStartupError = { "<b>global.mosDatumToolRadius</b> is not set. Run the configuration wizard to fix this (<b>G8000</b>)." }
        M99

    ; Add a datum tool at the last index in the tool table.
    M4000 S{"Datum Tool"} P{global.mosProbeToolID} R{global.mosDatumToolRadius}

; If we have a toolsetter, make sure the co-ordinates are set
if { global.mosFeatureToolSetter }
    if { !exists(global.mosToolSetterID) || global.mosToolSetterID == null }
        set global.mosStartupError = { "<b>global.mosToolSetterID</b> must contain the ID of the Toolsetter probe. Configure it using M558 K[probe-id]... in config.g, then run the configuration wizard (<b>G8000</b>)." }
        M99
    if { !exists(global.mosToolSetterPos) || global.mosToolSetterPos == null }
        set global.mosStartupError = { "<b>global.mosToolSetterPos</b> is not set. Run the configuration wizard to fix this (<b>G8000</b>)." }
        M99


if { !global.mosFeatureSpindleFeedback }
    if { !exists(global.mosSpindleAccelSeconds) || global.mosSpindleAccelSeconds == null }
        set global.mosStartupError = { "<b>global.mosSpindleAccelSeconds</b> is not set. Run the configuration wizard to fix this (<b>G8000</b>)." }
        M99

    if { !exists(global.mosSpindleDecelSeconds) || global.mosSpindleDecelSeconds == null }
        set global.mosStartupError = { "<b>global.mosSpindleDecelSeconds</b> is not set. Run the configuration wizard to fix this (<b>G8000</b>)." }
        M99

; Allow MOS macros to run.
set global.mosLoaded = true

if { global.mosExpertMode }
    echo { "WARNING: Expert mode is enabled! You will not see any modals describing what MillenniumOS is about to do, and will not be asked to confirm any actions!" }
