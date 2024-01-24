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
    if { !exists(global.mosTouchProbeReferencePos) || global.mosTouchProbeReferencePos == null }
        set global.mosStartupError = { "global.mosTouchProbeReferencePos is not set. Run the configuration wizard to fix this (G8000)." }
        M99
    if { !exists(global.mosTouchProbeRadius) || global.mosTouchProbeRadius == null }
        set global.mosStartupError = { "global.mosTouchProbeRadius is not set. Run the configuration wizard to fix this (G8000)." }
        M99
    if { !exists(global.mosTouchProbeDeflection) || global.mosTouchProbeDeflection == null }
        set global.mosStartupError = { "global.mosTouchProbeDeflection is not set. Run the configuration wizard to fix this (G8000)." }
        M99

; If we have a toolsetter, make sure the co-ordinates are set
if { global.mosFeatureToolSetter }
    if { !exists(global.mosToolSetterID) || global.mosToolSetterID == null }
        set global.mosStartupError = { "global.mosToolSetterID must contain the ID of the Toolsetter probe. Configure it using M558 K[probe-id]... in config.g, then run the configuration wizard (G8000)." }
        M99
    if { !exists(global.mosToolSetterPos) || global.mosToolSetterPos == null }
        set global.mosStartupError = { "global.mosToolSetterPos is not set. Run the configuration wizard to fix this (G8000)." }
        M99

if { global.mosFeatureTouchProbe }
    if { !exists(global.mosTouchProbeID) || global.mosTouchProbeID == null }
        set global.mosStartupError = { "global.mosTouchProbeID must contain the ID of the touch probe. Configure it using M558 K<probe-id>... in config.g, then run the configuration wizard (G8000)." }
        M99

; Allow MOS macros to run.
set global.mosLoaded = true

if { global.mosExpertMode }
    echo { "WARNING: Expert mode is enabled! You will not see any modals describing what MillenniumOS is about to do, and will not be asked to confirm any actions!" }
