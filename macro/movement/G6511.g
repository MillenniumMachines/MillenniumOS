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

; Start point in X/Y is directly above the reference surface.

var sX = { global.mosTouchProbeReferencePos[global.mosIX] }
var sY = { global.mosTouchProbeReferencePos[global.mosIY] }

; Start point in Z is the maximum height of the Axis (usually 0)
var sZ = { move.axes[global.mosIZ].max }

; Target point is the minimum height of the Axis (usually -120)
var tZ = { move.axes[global.mosIZ].min }

; Must have a touch probe to be able to probe the reference surface :)
if { !global.mosFeatureTouchProbe || global.mosTouchProbeToolID == null }
    abort { "Reference surface probing requires a touch probe." }

; This macro is called during a tool change so we can't call a tool
; change here as that would cause a recursion.
if { state.currentTool != global.mosTouchProbeToolID }
    abort { "Switching to the touch probe (<b>T" ^ global.mosTouchProbeToolID ^ "</b>) will automatically probe the reference surface if not already probed!" }

; Using the touch probe, probe downwards until the probe is triggered.
G6512 I{global.mosTouchProbeID} J{var.sX} K{var.sY} L{var.sZ} Z{var.tZ}

; Reference surface to toolsetter activation point distance
var dtS = { (global.mosTouchProbeReferencePos[global.mosIZ] - global.mosToolSetterPos[global.mosIZ])}

set global.mosToolSetterActivationPos = { global.mosProbeCoordinate[global.mosIZ] - var.dtS }

if { !global.mosExpertMode }
    echo { "MillenniumOS: Probed reference surface Z=" ^ global.mosProbeCoordinate[global.mosIZ] ^ ", expected toolsetter activation point is Z=" ^ global.mosToolSetterActivationPos }