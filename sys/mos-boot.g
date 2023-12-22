; mos-boot.g
;
; Load MillenniumOS.
; This involves sanity checking variables and aborting if they are not set.

; Confirm RRF is in CNC mode.
if { state.machineMode != "CNC" }
    abort { "MillenniumOS: Machine mode must be set to CNC using M453!" }

; If we have a toolsetter and touch probe, we can use the reference surface to
; perform fully automated tool setting. Make sure the user has provided the
; toolsetter height and reference surface co-ordinates.
if { global.mosFeatureTouchProbe && global.mosFeatureToolSetter }
    if { !exists(global.mosReferenceSurfaceCoords) }
        abort { "MillenniumOS: global.mosReferenceSurfaceCoords must contain X and Y machine co-ordinates of reference surface to probe!" }
    if { !exists(global.mosToolSetterHeight) }
        abort { "MillenniumOS: global.mosToolSetterHeight must contain measured height of toolsetter activation point from reference surface!" }

; If we have a toolsetter, make sure the co-ordinates are set
if { global.mosFeatureToolSetter }
    if { !exists(global.mosToolSetterID) || global.mosToolSetterID == null }
        abort { "MillenniumOS: global.mosToolSetterID must contain the ID of the Toolsetter probe. Configure it using M558 K<probe-id>... in config.g before loading MillenniumOS!" }
    if { !exists(global.mosToolSetterCoords) || global.mosToolSetterCoords == null }
        abort { "MillenniumOS: global.mosToolSetterCoords must contain X and Y machine co-ordinates of the center of the toolsetter surface!" }
if { global.mosFeatureTouchProbe }
    if { !exists(global.mosTouchProbeID) || global.mosTouchProbeID == null }
        abort { "MillenniumOS: global.mosTouchProbeID must contain the ID of the touch probe. Configure it using M558 K<probe-id>... in config.g before loading MillenniumOS!" }

; TODO: Make sure if we have a toolsetter but no touch probe, we can still compensate for tool length.

; Install daemon.g
if { fileexists("0:/sys/daemon.install") }
    echo { "MillenniumOS: Installing new daemon.g..." }
    if { fileexists("0:/sys/daemon.g") }
        M471 S"/sys/daemon.g" T"/sys/daemon.g.old" D1
    M471 S"/sys/daemon.install" T"/sys/daemon.g"

; Allow MOS macros to run.
set global.mosLoaded = true

echo { "MillenniumOS: Loaded version " ^ global.mosVersion ^ "!" }
if { global.mosExpertMode }
    echo { "WARNING: Expert mode is enabled! You will not see any modals describing what MillenniumOS is about to do, and will not be asked to confirm any actions!" }
