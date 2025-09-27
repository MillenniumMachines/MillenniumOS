; M4.9.g: SPINDLE ON, COUNTER-CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; USAGE: M4.9 [S<rpm>] [P<spindle-id>] [D<override-dwell-seconds>]

; Make sure this file is not executed by the secondary motion system
if !inputs[state.thisInput].active
    M99

; Validate Spindle ID parameter
if exists(param.P) && param.P < 0
    abort "Spindle ID must be a positive value!"

; Allocate Spindle ID
var sID = { (exists(param.P) ? param.P : global.nxtSID) }

; Validate Spindle ID
if var.sID < 0 || var.sID > #spindles-1 || spindles[var.sID] == null || spindles[var.sID].state == "unconfigured"
    abort { "Spindle ID " ^ var.sID ^ " is not valid!" }

; Validate Spindle direction
if !spindles[var.sID].canReverse
    abort { "Spindle #" ^ var.sID ^ " is not configured to allow counter-clockwise rotation!" }

; Validate Spindle Speed parameter
if exists(param.S)
    if param.S < 0
        abort { "Spindle speed for spindle #" ^ var.sID ^ " must be a positive value!" }

    ; If spindle speed is above 0, make sure it is above
    ; the minimum configured speed for the spindle.
    if param.S < spindles[var.sID].min && param.S > 0
        abort { "Spindle speed " ^ param.S ^ " is below minimum configured speed " ^ spindles[var.sID].min ^ " on spindle #" ^ var.sID ^ "!" }

    if param.S > spindles[var.sID].max
        abort { "Spindle speed " ^ param.S ^ " exceeds maximum configured speed " ^ spindles[var.sID].max ^ " on spindle #" ^ var.sID ^ "!" }

; Validate Dwell Time override parameter
if exists(param.D) && param.D < 0
    abort { "Dwell time must be a positive value!" }

; Wait for all movement to stop before continuing.
M400

; True if spindle is stopping
var sStopping = { spindles[var.sID].current > 0 && param.S == 0 }

; Warning Message for Operator
var wM = {"<b>CAUTION</b>: Spindle <b>#" ^ var.sID ^ "</b> will now start <b>counter-clockwise!</b><br/>Check that workpiece and tool are secure, and all safety precautions have been taken before pressing <b>Continue</b>."}

; If the spindle is stationary and not in expert mode, warn the operator
if spindles[var.sID].current == 0 && !global.nxtEM
    if global.nxtUiReady
        ; In future, this will send a message to the UI for confirmation
        ; For now, we fall back to M291
        M291 P{var.wM} R"NeXT: Warning" S4 K{"Continue", "Cancel"} F0
    else
        M291 P{var.wM} R"NeXT: Warning" S4 K{"Continue", "Cancel"} F0

    ; If operator picked cancel, then abort the job
    if input == 1
        abort "Operator aborted spindle startup!"

; Dwell time defaults to the previously timed spindle acceleration time.
var dwellTime = { global.nxtSAS }

; D parameter always overrides the dwell time
if exists(param.D)
    set var.dwellTime = { param.D }
else
    ; If we're changing spindle speed
    if exists(param.S)
        ; If this is a deceleration, adjust dT to use the deceleration timer
        if spindles[var.sID].current > param.S
            set var.dwellTime = { global.nxtSDS }

        ; Now calculate the change in velocity as a percentage
        set var.dwellTime = { ceil(var.dwellTime * (abs(spindles[var.sID].current - param.S) / spindles[var.sID].max) * 1.05) }

; All safety checks have now been passed, so we can start the spindle using M4 here.

; Account for all permutations of M4 command
if exists(param.S)
    if exists(param.P)
        M4 S{param.S} P{param.P}
    else
        M4 S{param.S}
elif exists(param.P)
    M4 P{param.P}
else
    M4

; If M4 returns an error, abort.
if result != 0
    abort { "Failed to control Spindle ID " ^ var.sID ^ "!" }

; If spindle feedback is enabled, then wait using the correct pin if it
; is defined, for speed changes or stopping.
var alreadyWaited = false

if global.nxtFeatSpindleFeedback
    if var.sStopping && global.nxtSFSID != null
        if !global.nxtEM
            echo { "NeXT: Waiting for spindle #" ^ var.sID ^ " to stop" }

        ; Wait for Spindle Feedback input to change state.
        M8004 K{global.nxtSFSID} D100 W30
        set var.alreadyWaited = true

    elif global.nxtSFCID != null
        if !global.nxtEM
            echo { "NeXT: Waiting for spindle #" ^ var.sID ^ " to reach the target speed" }

        ; Wait for Spindle Feedback input to change state.
        M8004 K{global.nxtSFCID} D100 W30
        set var.alreadyWaited = true

if !var.alreadyWaited
    if var.dwellTime > 0
        if !global.nxtEM
            echo { "NeXT: Waiting " ^ var.dwellTime ^ " seconds for spindle #" ^ var.sID ^ " to reach the target speed" }
        G4 S{var.dwellTime}
