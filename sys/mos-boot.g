; mos-boot.g
;
; Load MillenniumOS.
; This involves sanity checking variables and aborting if they are not set.

; Confirm RRF is in CNC mode.
if { state.machineMode != "CNC" }
    set global.mosStartupError = { "Machine mode must be set to CNC using M453!" }
    M99

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

    ; Add a dummy touch probe tool to RRF at the last position
    ; in the table.
    set global.mosTouchProbeToolID = {limits.tools-1}
    M563 R-1 S"Touch Probe" P{global.mosTouchProbeToolID}
    set global.mosToolTable[global.mosTouchProbeToolID] = {global.mosTouchProbeRadius, false, {0, 0}}


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
