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

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

G90
G21
G94

; If the touch probe or toolsetter feature is not enabled, we don't need to
; probe the reference surface but we must not abort - this command should be
; a no-op.
if { !global.mosFeatTouchProbe || !global.mosFeatToolSetter }
    M99

if { global.mosTSAP != null && (!exists(param.R) || param.R == 0) }
    echo { "Reference surface has already been probed! You can call G6511 R1 to force a re-probe." }
    M99

; If running in standalone mode, we are allowed to switch tools
; to the touch probe. When calling G6511 from _inside_ a tool change,
; we _MUST NOT_ switch tools (i.e. we must call with S0).
var standalone = { (exists(param.S)) ? (param.S != 0) : true }

; This macro is called during a tool change. When running _without_
; S0, we must switch to the probe tool and then exit.
; The tool change will handle connecting the touch probe, and trigger
; G6511 again with the S0 parameter which will allow us to run the
; reference surface probe.
if { state.currentTool != global.mosPTID }
    if { var.standalone }
        T{global.mosPTID}
        M99
    else
        abort { "Switching to the touch probe (<b>T" ^ global.mosPTID ^ "</b>) will automatically probe the reference surface if not already probed!" }

set global.mosTSAP = null

; Using the touch probe, probe downwards until the probe is triggered.
G6512 I{global.mosTPID} J{global.mosTPRP[0]} K{global.mosTPRP[1]} L{move.axes[2].max} Z{move.axes[2].min}

; Reference surface to toolsetter activation point distance
set global.mosTSAP = { global.mosMI[2] - (global.mosTPRP[2] - global.mosTSP[2]) }

if { !global.mosEM }
    echo { "MillenniumOS: Probed reference surface Z=" ^ global.mosMI[2] ^ ", expected toolsetter activation point is Z=" ^ global.mosTSAP }