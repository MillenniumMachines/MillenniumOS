; G6511.g: REFERENCE SURFACE PROBE - EXECUTE
;
; Probes a reference surface.
;
; The reference surface is used as a known Z-height which becomes the basis of our
; offset calculations for tools and work-piece surfaces.

; It should be a flat surface on the table of the machine which will not change in height
; during machining operations.

; When using a toolsetter, the distance between the toolsetter activation point and the
; reference surface should be a measurable value that _does not change_.

; This macro uses G6512 to perform the actual probing.

G90
G21
G94

; Must have a touch probe to be able to probe the reference surface :)
if { !global.mosFeatureTouchProbe || global.mosProbeToolID == null }
    abort { "Reference surface probing requires a touch probe." }

; This macro is called during a tool change so we can't call a tool
; change here as that would cause a recursion.
if { state.currentTool != global.mosProbeToolID }
    abort { "Switching to the touch probe (<b>T" ^ global.mosProbeToolID ^ "</b>) will automatically probe the reference surface if not already probed!" }

; Using the touch probe, probe downwards until the probe is triggered.
G6512 I{global.mosTouchProbeID} J{global.mosTouchProbeReferencePos[0]} K{global.mosTouchProbeReferencePos[1]} L{move.axes[2].max} Z{move.axes[2].min}

; Reference surface to toolsetter activation point distance
var dtS = { (global.mosTouchProbeReferencePos[2] - global.mosToolSetterPos[2])}

set global.mosToolSetterActivationPos = { global.mosProbeCoordinate[2] - var.dtS }

if { !global.mosExpertMode }
    echo { "MillenniumOS: Probed reference surface Z=" ^ global.mosProbeCoordinate[2] ^ ", expected toolsetter activation point is Z=" ^ global.mosToolSetterActivationPos }