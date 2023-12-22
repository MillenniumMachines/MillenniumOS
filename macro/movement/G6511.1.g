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
var zMin = { move.axes[global.mosIZ].min }
var zMax = { move.axes[global.mosIZ].max }

G6510.1 K{global.mosTouchProbeID} J{global.mosIZ} D{var.zMin} X{global.mosReferenceSurfaceCoords[global.mosIX]} Y{global.mosReferenceSurfaceCoords[global.mosIY]} Z{var.zMax}

if { result != 0 }
    abort { "Reference surface probing failed." }

set global.mosReferenceSurfaceZ = { global.mosProbeCoordinate }

echo { "MillenniumOS: Reference surface Z=" ^ global.mosReferenceSurfaceZ}