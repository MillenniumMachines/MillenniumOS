; mos-boot.g
;
; Load MillenniumOS.
; This generally just involves sanity checking variables and reporting to the
; operator that everything looks OK.

echo { "MillenniumOS v" ^ global.millenniumOSVersion ^ " loading..." }

; Confirm RRF is in CNC mode.
if { state.machineMode != "CNC" }
    abort { "Machine mode must be set to CNC using M453!" }

; If we have a toolsetter and touch probe, we can use the reference surface to
; perform fully automated tool setting. Make sure the user has provided the
; toolsetter height and reference surface co-ordinates.
if { global.featureTouchProbe && global.featureToolSetter }
    if { !exists(global.referenceSurfaceCoords) }
        abort { "global.referenceSurfaceCoords must contain X and Y machine co-ordinates of reference surface to probe!" }
    if { !exists(global.toolSetterHeight) }
        abort { "global.toolSetterHeight must contain measured height of toolsetter activation point from reference surface!" }

; If we have a toolsetter, make sure the co-ordinates are set
if { global.featureToolSetter }
    if { !exists(global.toolSetterCoords) }
        abort { "global.toolSetterCoords must contain X and Y machine co-ordinates of the center of the toolsetter surface!" }

; TODO: Make sure if we have a toolsetter but no touch probe, we can still compensate for tool length.
