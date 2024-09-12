; G81.g: DRILL CANNED CYCLE - FULL DEPTH

if { global.mosCCD == null }
    if { !exists(param.F) }
        abort { "Must specify feedrate (F...)" }

    if { !exists(param.R) }
        abort { "Must specify retraction plane (R...)" }

    if { !exists(param.Z) }
        abort { "Must specify Z position (Z...)" }

if { spindles[global.mosSID].current == 0 }
    abort { "Cannot run canned cycle with spindle off!" }

; Default the Z position to the previously stored mosCCD value
var tZ = { exists(param.Z) ? param.Z : global.mosCCD[0] }

; Default the feedrate to the previously stored mosCCD value
var tF = { exists(param.F) ? param.F : global.mosCCD[1] }

; Default the retraction plane to the previously stored mosCCD value
var tR = { exists(param.R) ? param.R : global.mosCCD[2] }

; Save the values globally so the canned cycle can be repeated
set global.mosCCD = { var.tZ, var.tF, var.tR }

G0 Z{var.tR} ; Make sure we're at the R plane

; If no X or Y is given, we're already above the hole
if { exists(param.X) && exists(param.Y) }
    G0 X{param.X} Y{param.Y} ; Move above the hole position
elif { exists(param.X) }
    G0 X{param.X} ; Move above the hole position
elif { exists(param.Y) }
    G0 Y{param.Y} ; Move above the hole position

G1 Z{var.tZ} F{var.tF} ; Feed down to the hole position
G0 Z{var.tR}           ; Retract to the R plane