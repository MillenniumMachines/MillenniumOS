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

; This is just for safety. It is good practice to park the machine and
; stop the spindle before calling any probing macro, and we should do
; this in any post-processor that targets the MillenniumOS Gcode Dialect,
; but we do this here just to make 100% certain that nobody is going to
; end up jogging the spindle around while it is running.
G27 Z1

; Default to null work offset, which will not set origin
; on a work offset.
var workOffset = null

;var probeNames = {"Vise Corner (X,Y,Z)", "Circular Bore (X,Y)", "Circular Boss (X,Y)", "Rectangle Pocket (X,Y)", "Rectangle Boss (X,Y)", "Outside Corner (X,Y)", "Single Surface (X/Y/Z)" }
var probeNames = { "Circular Bore (X,Y)", "Single Surface (X/Y/Z)" }

if { !global.mosExpertMode && !global.mosDescProbeWorkpieceDisplayed }
    M291 P{"Before executing cutting operations, it is necessary to identify where the workpiece for a part is. We will do this by probing and setting a work co-ordinate system (WCS) origin point."} R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{"The origin of a WCS is the reference point for subsequent cutting operations, and must match the chosen reference point in your CAM software."} R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{"You will need to select an appropriate probe cycle type (or types!) based on the shape of your workpiece."} R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{"For a square or rectangular workpiece, you should start with the <b>Vise Corner</b> probing cycle to identify your origin corner and Z height."} R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{"For a round workpiece, you should start with the <b>Circular Boss</b> and <b>Single Surface (Z)</b> cycle to identify the center of the circle as your origin and Z height."} R"MillenniumOS: Probe Workpiece" T0 S2

    ; If user does not have a touch probe configured,
    ; walk them through the manual probing procedure.
    if { global.mosTouchProbeToolID == null }
        M291 P{"Your machine does not have a touch probe configured, so probing will involve manually jogging the machine until an installed tool or metal dowel touches the workpiece."} R"MillenniumOS: Probe Workpiece" T0 S2
        M291 P{"You will be walked through this process so it should be relatively foolproof, but <b>it is possible to damage your tool, spindle or workpiece</b> if you press the wrong jog button!"} R"MillenniumOS: Probe Workpiece" T0 S2
    set global.mosDescProbeWorkpieceDisplayed = true

; Ask user for work offset to set.
if { !exists(param.W) }
    M291 P{"Select WCS number to set origin on or press ""None"" to probe without setting WCS origin"} R"MillenniumOS: Probe Workpiece" T0 S4 K{global.mosWorkOffsetCodes}
    if { result != 0 }
        abort {"Operator cancelled probe cycle, please set WCS origin manually or restart probing with <b>G6600</b>"}
        M99

    set var.workOffset = { input }

    if { var.workOffset == 0 }
        set var.workOffset = null
else
    set var.workOffset = { param.W }

; Warn about null work offset
if { var.workOffset == null && !global.mosExpertMode }
    M291 P{"Probing can still run without a WCS origin being set. The output of the probing cycle will be available in the global variables specific to the probe cycle."} R"MillenniumOS: Probe Workpiece" T0 S2

; If WCS is set via parameter, warn about setting WCS origin
if { exists(param.W) && !global.mosExpertMode }
    M291 P{"Probing will set the origin of WCS " ^ var.workOffset ^ " (" ^ global.mosWorkOffsetCodes[var.workOffset] ^ ") to the probed location."} R"MillenniumOS: Probe Workpiece" T0 S2

; Show operator existing WCS origin co-ordinates.
if { var.workOffset != null }
    ; Get work offset name (G54, G55, etc) and origin co-ordinates
    var workOffsetName = { global.mosWorkOffsetCodes[var.workOffset] }
    var pdX = { move.axes[global.mosIX].workplaceOffsets[var.workOffset-1] }
    var pdY = { move.axes[global.mosIY].workplaceOffsets[var.workOffset-1] }
    var pdZ = { move.axes[global.mosIZ].workplaceOffsets[var.workOffset-1] }

    ; If not expert mode, show operator the WCS origin if any axes are set.
    if { !global.mosExpertMode && (var.pdX != 0 || var.pdY != 0 || var.pdZ != 0) }
        M291 P{"WCS " ^ var.workOffset ^ " (" ^ var.workOffsetName ^ ") has origin:<br/>X=" ^ var.pdX ^ " Y=" ^ var.pdY ^ " Z=" ^ var.pdZ} R"MillenniumOS: Probe Workpiece" T0 S2

    ; If work offset origin is already set
    if { var.pdx != 0 && var.pdY != 0 && var.pdZ != 0 }
        ; Allow operator to continue without resetting the origin and abort the probe
        M291 P{"WCS " ^ var.workOffset ^ " (" ^ var.workOffsetName ^ ") already has a valid origin.<br/>Click <b>Continue</b> to use the existing origin, or <b>Reset</b> to probe it again."} R"MillenniumOS: Probe Workpiece" T0 S4 K{"Continue","Reset"} F0
        if { input == 0 }
            echo {"MillenniumOS: WCS " ^ var.workOffset ^ " (" ^ var.workOffsetName ^ ") origin retained, skipping probe cycle."}
            M99

        ; Force reset the origin as a safety measure.
        G10 L2 P{var.workOffset} X0 Y0 Z0
        echo {"MillenniumOS: WCS " ^ var.workOffset ^ " (" ^ var.workOffsetName ^ ") origin reset."}

; Switch to touchprobe if not already connected
var needsTouchProbe = { global.mosTouchProbeToolID != null && global.mosTouchProbeToolID != state.currentTool }
if { var.needsTouchProbe }
    T T{global.mosTouchProbeToolID}

; Prompt the user to pick a probing operation.
M291 P"Please select a probe cycle type." R"MillenniumOS: Probe Workpiece" T0 S4 F0 K{var.probeNames}
if { result != 0 }
    abort { "Operator cancelled probe cycle!" }

; Run the selected probing operation.
; We cannot lookup G command numbers to run dynamically so these must be
; hardcoded in a set of if statements.
var probeOp = { input }

if { exists(var.probeOp) && var.probeOp != null }
    ; It is not possible to check the return status
    ; of a meta macro, so we must assume that these macros are
    ; going to abort themselves if there is a problem.
    if { var.probeOp == 0 }
        G6500 W{var.workOffset}
    elif { var.probeOp == 1 }
        G6510 W{var.workOffset}
    else
        abort { "Invalid probe operation " ^ var.probeOp ^ " selected!" }

    if { var.workOffset != null }
        var poX = { move.axes[global.mosIX].workplaceOffsets[var.workOffset-1] }
        var poY = { move.axes[global.mosIY].workplaceOffsets[var.workOffset-1] }
        var poZ = { move.axes[global.mosIZ].workplaceOffsets[var.workOffset-1] }

        var paZ = { (var.poX == 0)? " " ^ global.mosN[global.mosIX] : "" }
        set var.paZ = { var.paZ ^ ((var.poY == 0)? " " ^ global.mosN[global.mosIY] :"") }
        set var.paZ = { var.paZ ^ ((var.poZ == 0)? " " ^ global.mosN[global.mosIZ] :"") }

        if { var.paZ != "" }
            M291 P{"Probe cycle complete, but axes<b>" ^ var.paZ ^ "</b> in <b>WCS " ^ var.workOffset ^ "</b> have not been probed yet. Run another probe cycle?"} R"MillenniumOS: Probe Workpiece" T0 S4 K{"Yes", "No"}
            if { input == 0 }
                ; This is a recursive call. Let the user break it :)
                G6600 W{var.workOffset}