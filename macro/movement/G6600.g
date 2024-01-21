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

; Default to null work offset, which will not set origin
; on a work offset.
var workOffset = null

var probeNames = {"Vise Corner (X,Y,Z)", "Circular Bore (X,Y)", "Circular Boss (X,Y)", "Rectangle Pocket (X,Y)", "Rectangle Boss (X,Y)", "Outside Corner (X,Y)", "Single Surface (X/Y/Z)" }

; Ask user for work offset to set.
if { !exists(param.W) }
    M291 P"Select WCS number to set origin on or press "None" to probe without setting WCS origin" R"Set WCS Origin?" T0 S4 K{global.mosWorkOffsetCodes}
    if { result != 0 }
        abort { "Operator cancelled probing operation!" }

    set var.workOffset = { input }

    if { var.workOffset == 0 }
        set var.workOffset = null
else
    set var.workOffset = { param.W }

if { exists(var.workOffset) }
    echo { "G6600 Work Offset: " ^ var.workOffset}
    ; Prompt the user to pick a probing operation.
    M291 P"Select a probing operation:" R"Probe Work piece" J1 T0 S4 F0 K{var.probeNames}
    if { result != 0 }
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

    ; "Vice Corner" is a 3 axis probe, all others are X/Y
    if { var.probeOp != 0 }
        echo { "Please probe Z axis to set work origin zero"}