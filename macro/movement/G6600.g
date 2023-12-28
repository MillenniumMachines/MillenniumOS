; G6600.g: PROBE WORK PIECE
;
; Meta macro to prompt the user to probe a work piece.
; Takes a single optional parameter, W<work-offset> and guides
; the user through the process of probing the work piece.
; If the W parameter is specified, the work offset origin will
; be set to the probed location.

; 1. Prompt the user for the type of probing operation they need
; 2. Run the meta macro for the selected probing operation, which will
;    prompt the user for the probe parameters. The meta macro will then
;    call the appropriate probing macro.

; Default to null work offset, which will not set any offset.
var workOffset = { (exists(param.W) ? param.W : null ) }

var probeNames = {
    "Vise Corner",
    "Bore",
    "Boss",
    "Rectangle Pocket",
    "Outside Corner",
    "Single Surface",
}

; Prompt the user to pick a probing operation.
M291 P"Select a probing operation:" R"Probe Work piece" J1 T0 S4 F"0" K{var.probeNames}
if result != 0
    abort { "Operator cancelled probing operation!" }

; Run the selected probing operation.
; We cannot lookup G command numbers to run dynamically so these must be
; hardcoded in a set of if statements.
var probeOp = { input }

if { var.probeOp == 0 }
    G6520 W{var.workOffset}
elif { var.probeOp == 1 }
    G6500 W{var.workOffset}
elif { var.probeOp == 2 }
    G6501 W{var.workOffset}
elif { var.probeOp == 3 }
    G6502 W{var.workOffset}
elif { var.probeOp == 4 }
    G6508 W{var.workOffset}
elif { var.probeOp == 5 }
    G6510 W{var.workOffset}
else
    abort { "Invalid probing operation!" }