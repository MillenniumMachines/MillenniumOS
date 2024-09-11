; M3.9.g: SPINDLE ON, CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; It takes a bit of time to spin up the spindle. How long this
; requires depends on the VFD setup and the spindle power. The spindle
; needs to be controlled by both the firmware (for pause / resume
; amongst other things) and the post-processor, so we need an m-code
; that can be used by both and that means our wait-for-spindle dwell
; time only needs to exist in one place.
; USAGE: M3.9 [S<rpm>] [P<spindle-id>] [D<override-dwell-seconds>]

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate Spindle ID parameter
if { exists(param.P) && param.P < 0 }
    abort { "Spindle ID must be a positive value!" }

; Allocate Spindle ID
var sID = { (exists(param.P) ? param.P : global.mosSID) }

; Validate Spindle Speed parameter
if { exists(param.S) }
    if { param.S < 0 }
        abort { "Spindle speed for spindle #" ^ var.sID ^ " must be a positive value!" }

    ; If spindle speed is above 0, make sure it is above
    ; the minimum configured speed for the spindle.
    if { param.S < spindles[var.sID].min && param.S > 0 }
        abort { "Spindle speed " ^ param.S ^ " is below minimum configured speed " ^ spindles[var.sID].min ^ " on spindle #" ^ var.sID ^ "!" }

    if { param.S > spindles[var.sID].max }
        abort { "Spindle speed " ^ param.S ^ " exceeds maximum configured speed " ^ spindles[var.sID].max ^ " on spindle #" ^ var.sID ^ "!" }

; Validate Dwell Time override parameter
if { exists(param.D) && param.D < 0 }
    abort { "Dwell time must be a positive value!" }

; Wait for all movement to stop before continuing.
M400

; True if spindle is stopping
var sStopping = { spindles[var.sID].current > 0 && param.S == 0 }

; Warning Message for Operator
var wM = {"<b>CAUTION</b>: Spindle <b>#" ^ var.sID ^ "</b> will now start!<br/>Check that workpiece and tool are secure, and all safety precautions have been taken before pressing <b>Continue</b>."}

; If the spindle is stationary
if { spindles[var.sID].current == 0 }
    ; If we're running a job, expert mode is turned off,
    ; and we're not paused, pausing or resuming, then warn
    ; the operator and allow them to pause or abort the job.
    if { job.file.fileName != null && !global.mosEM && state.status != "resuming" && state.status != "pausing" && state.status != "paused" }
        M291 P{var.wM} R"MillenniumOS: Warning" S4 K{"Continue", "Pause", "Cancel"} F0
        ; If operator picked pause, then pause the machine
        if { input == 1 }
            M291 P{ "<b>CAUTION</b>: The job has been paused. Clicking <b>Resume Job</b> will start the spindle <b>INSTANTLY</b>, with no confirmation.<br/><b>BE CAREFUL!</b>" } R"MillenniumOS: Warning" S2 T0
            M25
        ; If operator picked cancel, then abort the job
        elif { input == 2 }
            abort { "Operator aborted spindle startup!" }

    ; Otherwise just warn the operator and allow them to
    ; abort, if expert mode is turned off.
    elif { !global.mosEM }
        M291 P{var.wM} R"MillenniumOS: Warning" S4 K{"Continue", "Cancel"} F0
        ; If operator picked cancel, then abort the job
        if { input == 1 }
            abort { "Operator aborted spindle startup!" }


; Dwell time defaults to the previously timed spindle acceleration time.
; If using spindle feedback, this will likely be a null value and is
; unused anyway.

; This assumes the spindle is accelerating from a stop.
var dwellTime = { global.mosSAS }

; Must calculate dwell time before spindle speed is changed.
; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }
else
    ; If we're changing spindle speed
    if { exists(param.S) }

        ; If this is a deceleration, adjust dT to use the deceleration timer
        if { spindles[var.sID].current > param.S }
            set var.dwellTime = { global.mosSDS }

        ; Now calculate the change in velocity as a percentage
        ; of the maximum spindle speed, and multiply the dwell time
        ; by that percentage with 5% extra leeway.
        ; Ceil this so we always wait a round second, no point waiting
        ; less than 1 anyway.
        set var.dwellTime = { ceil(var.dwellTime * (abs(spindles[var.sID].current - param.S) / spindles[var.sID].max) * 1.05) }

; All safety checks have now been passed, so we can
; start the spindle using M3 here.

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
    abort { "Failed to control Spindle ID " ^ var.sID ^ "!" }

; If spindle feedback is enabled, then wait using the correct pin if it
; is defined, for speed changes or stopping.
var alreadyWaited = false

if { global.mosFeatSpindleFeedback }
    if { var.sStopping && global.mosSFSID != null }
        if { !global.mosEM }
            echo { "MillenniumOS: Waiting for spindle #" ^ var.sID ^ " to stop" }

        ; Wait for Spindle Feedback input to change state.
        ; Wait a maximum of 30 seconds, or abort.
        M8004 K{global.mosSFSID} D100 W30
        set var.alreadyWaited = true

    elif { global.mosSFCID != null }
        if { !global.mosEM }
            echo { "MillenniumOS: Waiting for spindle #" ^ var.sID ^ " to reach the target speed" }

        ; Wait for Spindle Feedback input to change state.
        ; Wait a maximum of 30 seconds, or abort.
        M8004 K{global.mosSFCID} D100 W30
        set var.alreadyWaited = true

if { !var.alreadyWaited }
    if { var.dwellTime > 0 }
        if { !global.mosEM }
            echo { "MillenniumOS: Waiting " ^ var.dwellTime ^ " seconds for spindle #" ^ var.sID ^ " to reach the target speed" }
        G4 S{var.dwellTime}
