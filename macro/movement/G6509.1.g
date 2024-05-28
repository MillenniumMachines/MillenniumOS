; G6509.1.g: INSIDE CORNER PROBE - EXECUTE
;
; Probe an inside corner of a workpiece, set target WCS X and Y
; co-ordinates to the probed corner, if requested.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.H) || param.H < 0 || param.H > (#global.mosCN-1) }
    abort "Must provide valid corner index (H..)!"

if { !exists(param.I) }
    abort "Must provide distance inward from corner to probe, in mm (I..)!"

var maxWCS = #global.mosWON
if { exists(param.W) && (param.W < 1 || param.W > var.maxWCS) }
    abort { "WCS number (W..) must be between 1 and " ^ var.maxWCS ^ "!" }

; J = start position X
; K = start position Y
; L = start position Z - our probe height

; TODO: Don't use min and max machine positions here,
; only probe a limited distance from the start position.

; Calculate all possible movement directions
; We only pick one of these depending on the corner selected
;             FL                           FR                           RR                           RL
var dirX  = { move.axes[0].max, move.axes[0].min, move.axes[0].min, move.axes[0].max  }
var dirY  = { move.axes[1].max, move.axes[1].max, move.axes[1].min, move.axes[1].min  }

; Calculate all possible start positions
; Again, we only pick one of these depending on the corner selected
;            FL                 FR                 RR                 RL
var sX   = { param.J + param.I, param.J - param.I, param.J - param.I, param.J + param.I }
var sY   = { param.K + param.I, param.K + param.I, param.K - param.I, param.K - param.I }

; Probe edge on X axis
G6512 K{ global.mosTPP[0] } J{ var.sX[param.H] } K{ var.sY[param.H] } L{ param.L } X{ var.dirX[param.H] }

; Probe edge on Y axis
G6512 K{ global.mosTPP[0] } J{ var.sX[param.H] } K{ var.sY[param.H] } L{ param.L } Y{ var.dirY[param.H] }

; Set most recent corner position variables
set global.mosOutsideCornerNum = param.H
set global.mosOutsideCornerPos = { global.mosPC[0], global.mosPC[1] }

if { !exists(param.R) || param.R != 0 }
    if { !global.mosEM }
        echo { "Outside " ^ global.mosCN[param.H] ^ " corner is { " ^ global.mosOutsideCornerPos ^ " }" }
    else
        echo { "global.mosOutsideCornerNum=" ^ global.mosOutsideCornerNum }
        echo { "global.mosOutsideCornerPos=" ^ global.mosOutsideCornerPos }

; Set WCS origin to the probed corner, if requested
if { exists(param.W) }
    echo { "Setting WCS " ^ param.W ^ " X,Y origin." }
    G10 L2 P{ param.W } X{ global.mosPC[0] } Y{ global.mosPC[1] }