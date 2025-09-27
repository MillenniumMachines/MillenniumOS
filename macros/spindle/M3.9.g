; M3.9.g: SPINDLE ON, CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; USAGE: M3.9 [S<rpm>] [P<spindleID>] [D<overrideDwellSeconds>]

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate Spindle ID parameter
if { exists(param.P) && param.P < 0 }
    abort "Spindle ID must be a positive value!"

; Allocate Spindle ID
var spindleID = { (exists(param.P) ? param.P : global.nxtSpindleID) }

; Validate Spindle ID
if { var.spindleID < 0 || var.spindleID > #spindles-1 || spindles[var.spindleID] == null || spindles[var.spindleID].state == "unconfigured" }
    abort { "Spindle ID " ^ var.spindleID ^ " is not valid!" }

; Validate Spindle Speed parameter
if { exists(param.S) }
    if { param.S < 0 }
        abort { "Spindle speed for spindle #" ^ var.spindleID ^ " must be a positive value!" }

    ; If spindle speed is above 0, make sure it is above
    ; the minimum configured speed for the spindle.
    if { param.S < spindles[var.spindleID].min && param.S > 0 }
        abort { "Spindle speed " ^ param.S ^ " is below minimum configured speed " ^ spindles[var.spindleID].min ^ " on spindle #" ^ var.spindleID ^ "!" }

    if { param.S > spindles[var.spindleID].max }
        abort { "Spindle speed " ^ param.S ^ " exceeds maximum configured speed " ^ spindles[var.spindleID].max ^ " on spindle #" ^ var.spindleID ^ "!" }

; Validate Dwell Time override parameter
if { exists(param.D) && param.D < 0 }
    abort { "Dwell time must be a positive value!" }

; Wait for all movement to stop before continuing.
M400

; True if spindle is stopping
var spindleStopping = { spindles[var.spindleID].current > 0 && param.S == 0 }

; Warning Message for Operator
var warningMessage = {"<b>CAUTION</b>: Spindle <b>#" ^ var.spindleID ^ "</b> will now start <b>clockwise</b>!<br/>Check that workpiece and tool are secure, and all safety precautions have been taken before pressing <b>Continue</b>."}

; If the spindle is stationary and not in expert mode, warn the operator
if { spindles[var.spindleID].current == 0 && !global.nxtExpertMode }
    if { global.nxtUiReady }
        M1000 P{var.warningMessage} R"NeXT: Warning" K{"Continue", "Cancel"} F0
    else
        M291 P{var.warningMessage} R"NeXT: Warning" S4 K{"Continue", "Cancel"} F0

    ; If operator picked cancel, then abort the job
    if { input == 1 }
        abort "Operator aborted spindle startup!"

; Dwell time defaults to the previously timed spindle acceleration time.
var dwellTime = { global.nxtSpindleAccelSec }

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }
else
    ; If we're changing spindle speed
    if { exists(param.S) }
        ; If this is a deceleration, adjust dT to use the deceleration timer
        if { spindles[var.spindleID].current > param.S }
            set var.dwellTime = { global.nxtSpindleDecelSec }

        ; Now calculate the change in velocity as a percentage
        set var.dwellTime = { ceil(var.dwellTime * (abs(spindles[var.spindleID].current - param.S) / spindles[var.spindleID].max) * 1.05) }

; All safety checks have now been passed, so we can start the spindle using M3 here.

; Account for all permutations of M3 command
if { exists(param.S) }
    if { exists(param.P) }
        M3 S{param.S} P{param.P}
    else
        M3 S{param.S}
elif { exists(param.P) }
    M3 P{param.P}
else
    M3

; If M3 returns an error, abort.
if { result != 0 }
    abort { "Failed to control Spindle ID " ^ var.spindleID ^ "!" }

if { var.dwellTime > 0 }
    if { !global.nxtExpertMode }
        echo { "NeXT: Waiting " ^ var.dwellTime ^ " seconds for spindle #" ^ var.spindleID ^ " to reach the target speed" }
    G4 S{var.dwellTime}
