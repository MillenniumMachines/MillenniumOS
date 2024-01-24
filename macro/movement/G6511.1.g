; G6511.1.g: REFERENCE SURFACE PROBE - EXECUTE
;
; Probes a reference surface.
;
; The reference surface is used as a known Z-height which becomes the basis of our
; offset calculations for tools and work-piece surfaces.

; It should be a flat surface on the table of the machine which will not change in height
; during machining operations.

; When using a toolsetter, the distance between the toolsetter activation point and the
; reference surface should be a measurable value that _does not change_.

; This macro uses G6510.1 to perform the actual probing.

G90
G21

; Start point in X/Y is directly above the reference surface.
var sX = { global.mosReferenceSurfacePos[global.mosIX] }
var sY = { global.mosReferenceSurfacePos[global.mosIY] }

; Start point in Z is the maximum height of the Axis (usually 0)
var sZ = { move.axes[global.mosIZ].max }

; Target point is the minimum height of the Axis (usually -120)
var tZ = { move.axes[global.mosIZ].min }

; Using the touch probe, probe downwards until the probe is triggered.
G6510.1 I{global.mosTouchProbeID} J{var.sX} K{var.sY} L{var.sZ} Z{var.tZ}

if { result != 0 }
    abort { "Reference surface probing failed." }

; Extract the Z-height of the reference surface from the probe result.
set global.mosReferenceSurfaceZ = { global.mosProbeCoordinate[global.mosIZ] }

echo { "MillenniumOS: Reference surface Z=" ^ global.mosReferenceSurfaceZ}