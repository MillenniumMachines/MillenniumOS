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

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { spindles[global.mosSID].current != 0 }
    echo { "Spindle should be stopped before probing! Parking now..."}
    G27 Z1

if { !exists(global.mosLdd) || !global.mosLdd }
    abort {"MillenniumOS is not loaded! Please restart your mainboard and check for any startup errors!"}

; Default workOffset to the current workplace number if not specified
; with the W parameter.
; This specifically _allows_ W to be null - this is used by the public
; 'Probe Workpiece' macro, to allow the user to select the WCS
; they want to probe.
var workOffset = { (exists(param.W)) ? param.W : move.workplaceNumber }

; Define names for work offsets. The work offset ID is the index into these arrays.
; None means do not set origins on a work offset.
var workOffsetCodes={"G54","G55","G56","G57","G58","G59","G59.1","G59.2","G59.3"}


; Define probe cycle names
var probeCycleNames = { "Vise Corner (X,Y,Z)", "Circular Bore (X,Y)", "Circular Boss (X,Y)", "Rectangle Pocket (X,Y)", "Rectangle Block (X,Y)", "Web (X/Y)", "Pocket (X/Y)", "Outside Corner (X,Y)", "Single Surface (X/Y/Z)" }

if { global.mosTM && !global.mosDD[0] }
    M291 P{"Before executing cutting operations, it is necessary to identify where the workpiece for a part is. We will do this by probing and setting a work co-ordinate system (WCS) origin point."} R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{"The origin of a WCS is the reference point for subsequent cutting operations, and must match the chosen reference point in your CAM software."} R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{"You will need to select an appropriate probe cycle type (or types!) based on the shape of your workpiece."} R"MillenniumOS: Probe Workpiece" T0 S2

    ; If user does not have a touch probe configured,
    ; walk them through the manual probing procedure.
    if { ! global.mosFeatTouchProbe }
        M291 P{"Your machine does not have a <b>Touch Probe</b> configured, so probing will involve manually jogging the machine until an installed tool or metal dowel touches the workpiece."} R"MillenniumOS: Probe Workpiece" T0 S2

    if { global.mosFeatToolSetter }
        M291 P{"For a square or rectangular workpiece whose top surface is above any work holding, you can start with the <b>Vise Corner</b> cycle to identify your origin corner in X and Y, and Z height."} R"MillenniumOS: Probe Workpiece" T0 S2
        M291 P{"For a round workpiece, you can start with the <b>Circular Boss</b> and <b>Single Surface (Z)</b> cycle to identify the center of the item as your origin in X and Y, and Z height."} R"MillenniumOS: Probe Workpiece" T0 S2
    else
        ; If the user does not have a toolsetter, then they need to
        ; reset the Z origin on every toolchange anyway.
        M291 P{"Your machine does not have a <b>Toolsetter</b> so you will be guided through re-probing the Z origin during each tool change.<br/>You can safely skip probing on the Z axis at this point."} R"MillenniumOS: Probe Workpiece" T0 S2
        M291 P{"For a square or rectangular workpiece, you should start with the <b>Outside Corner</b> probing cycle to identify your origin corner in X and Y."} R"MillenniumOS: Probe Workpiece" T0 S2
        M291 P{"For a round workpiece, you should start with the <b>Circular Boss</b> cycle to identify the center of the circle as your origin in X and Y."} R"MillenniumOS: Probe Workpiece" T0 S2

    M291 P{"<b>NOTE</b>: Surfaces are named assuming that you (the operator) are standing in front of the machine, with the Z column at the <b>BACK</b>."} R"MillenniumOS: Probe Workpiece" T0 S2

    set global.mosDD[0] = true

; Ask user for work offset to set if no workplace is set or
; a W parameter was not passed.

if { var.workOffset == null }
    M291 P{"Select the WCS to probe. The current WCS is selected by default."} R"MillenniumOS: Probe Workpiece" J2 T0 S4 K{var.workOffsetCodes} F{move.workplaceNumber}
    if { result != 0 }
        abort {"Operator cancelled probe cycle, please set WCS origin manually or restart probing with <b>G6600</b>!"}
        M99

    set var.workOffset = { input }

; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Get work offset name (G54, G55, etc) and origin co-ordinates
var workOffsetName = { var.workOffsetCodes[var.workOffset] }
var pdX = { move.axes[0].workplaceOffsets[var.workOffset] }
var pdY = { move.axes[1].workplaceOffsets[var.workOffset] }
var pdZ = { move.axes[2].workplaceOffsets[var.workOffset] }

; If tutorial mode, show operator the WCS origin if any axes are set.
if { global.mosTM }
    if { (var.pdX != 0 || var.pdY != 0 || var.pdZ != 0) }
        M291 P{"WCS " ^ var.wcsNumber ^ " (" ^ var.workOffsetName ^ ") has origin:<br/>X=" ^ var.pdX ^ " Y=" ^ var.pdY ^ " Z=" ^ var.pdZ} R"MillenniumOS: Probe Workpiece" T0 S2
    else
        ; Otherwise, tell the operator which WCS origin will be set.
        M291 P{"Probing will set the origin of WCS " ^ var.wcsNumber ^ " (" ^ var.workOffsetCodes[var.workOffset] ^ ") to the probed location."} R"MillenniumOS: Probe Workpiece" T0 S3 J2
        if { result != 0 }
            abort {"Operator cancelled probe cycle, please set WCS origin manually or restart probing with <b>G6600</b>!"}

; If work offset origin is already set
if { var.pdX != 0 && var.pdY != 0 && var.pdZ != 0 }
    ; Allow operator to continue without resetting the origin and abort the probe
    M291 P{"WCS " ^ var.wcsNumber ^ " (" ^ var.workOffsetName ^ ") is valid. <br/><b>Continue</b> to proceed, <b>Modify</b> to update or <b>Reset</b> to start again."} R"MillenniumOS: Probe Workpiece" T0 S4 K{"Continue","Modify", "Reset"} F0
    if { input == 0 }
        echo {"MillenniumOS: WCS " ^ var.wcsNumber ^ " (" ^ var.workOffsetName ^ ") origin retained, skipping probe cycle."}
        M99
    elif { input == 2 }
        echo {"MillenniumOS: WCS " ^ var.wcsNumber ^ " (" ^ var.workOffsetName ^ ") origin has been reset."}
        ; Reset the WCS origin so that all axes must be re-probed.
        G10 L2 P{var.wcsNumber} X0 Y0 Z0

        ; Clear all stored WCS details
        M5010 W{var.workOffset}

; Switch to touchprobe if not already connected
if { global.mosPTID != state.currentTool }
    T T{global.mosPTID}

; Prompt the user to pick a probing operation.
M291 P"Please select a probe cycle type." R"MillenniumOS: Probe Workpiece" J2 T0 S4 F0 K{var.probeCycleNames}
if { result != 0 }
    abort {"Operator cancelled probe cycle, please set WCS origin manually or restart probing with <b>G6600</b>!"}

; Cancel rotation compensation as we use G53 on the probe moves.
G69

; Reset the current probe status counts
M5012

; Run the selected probing operation.
; We cannot lookup G command numbers to run dynamically so these must be
; hardcoded in a set of if statements.

; It is not possible to check the return status
; of a meta macro, so we must assume that these macros are
; going to abort themselves if there is a problem.
if { input == 0 } ; Vise Corner
    G6520 W{var.workOffset}
elif { input == 1 } ; Circular Bore
    G6500 W{var.workOffset}
elif { input == 2 } ; Circular Boss
    G6501 W{var.workOffset}
elif { input == 3 } ; Rectangle Pocket
    G6502 W{var.workOffset}
elif { input == 4 } ; Rectangle Block
    G6503 W{var.workOffset}
elif { input == 5 } ; Web X/Y
    G6504 W{var.workOffset}
elif { input == 6 } ; Pocket X/Y
    G6505 W{var.workOffset}
elif { input == 7 } ; Outside Corner
    G6508 W{var.workOffset}
elif { input == 8 } ; Single Surface
    G6510 W{var.workOffset}
else
    abort { "Invalid probe operation " ^ input ^ " selected!" }

if { var.workOffset != null }
    var paZ = { (move.axes[0].workplaceOffsets[var.workOffset] == 0)? " X" : "" }
    set var.paZ = { var.paZ ^ ((move.axes[1].workplaceOffsets[var.workOffset] == 0)? " Y" : "") }

    ; Only warn about Z if toolsetter is enabled.
    ; Without a toolsetter, the first tool change
    ; will prompt to zero the Z height again.
    if { global.mosFeatToolSetter }
        set var.paZ = { var.paZ ^ ((move.axes[2].workplaceOffsets[var.workOffset] == 0)? " Z" : "") }

    if { var.paZ != "" }
        M291 P{"Probe cycle complete, but axes<b>" ^ var.paZ ^ "</b> in <b>WCS " ^ var.wcsNumber ^ "</b> have not been probed yet. Run another probe cycle?"} R"MillenniumOS: Probe Workpiece" T0 S4 K{"Yes", "No"}
        if { input == 0 }
            ; This is a recursive call. Let the user break it :)
            G6600 W{var.workOffset}
            M99

    else
        M291 P{"WCS " ^ var.wcsNumber ^ " (" ^ var.workOffsetCodes[var.workOffset] ^ ") origin is valid.<br/>Click <b>Continue</b> to proceed or <b>Re-Probe</b> to try again."} R"MillenniumOS: Probe Workpiece" T0 J2 S4 K{"Continue", "Re-Probe"}
        if { result != 0 }
            abort {"Operator cancelled probe cycle, please set WCS origin manually or restart probing with <b>G6600</b>!"}
        elif { input == 1 }
            ; This is a recursive call. Let the user break it :)
            G6600 W{var.workOffset}
            M99

    ; Save restore details to config-override.g
    M500.1

    echo { "MillenniumOS: WCS Origins have been saved and can be restored on reboot."}
