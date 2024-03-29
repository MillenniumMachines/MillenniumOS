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

if { exists(param.P) && param.P < 0 }
    abort { "Spindle ID must be a positive value!" }

; Allocate spindle ID
var sID = { (exists(param.P) ? param.P : global.mosSID) }

if { exists(param.S) }
    if { param.S < 0 }
        abort { "Spindle speed must be a positive value!" }
    if { param.S > spindles[var.sID].max }
        abort { "Spindle speed " ^ param.S ^ " exceeds maximum configured speed " ^ spindles[var.sID].max ^ " on spindle #" ^ var.sID ^ "!" }

if { exists(param.D) && param.D < 0 }
    abort { "Dwell time must be a positive value!" }

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
            abort { "Operator paused spindle startup!" }

    ; Otherwise just warn the operator and allow them to
    ; abort, if expert mode is turned off.
    elif { !global.mosEM }
        M291 P{var.wM} R"MillenniumOS: Warning" S4 K{"Continue", "Cancel"} F0
        ; If operator picked cancel, then abort the job
        if { input == 1 }
            abort { "Operator aborted spindle startup!" }

; Must calculate dwell time before spindle speed is changed.

; Dwell time defaults to the previously timed spindle acceleration time.
; This assumes the spindle is accelerating from a stop.
var dT = { global.mosSAS }

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dT = { param.D }
else
    ; If we're changing spindle speed
    if { exists(param.S) }

        ; If this is a deceleration, adjust dT
        if { spindles[var.sID].current > param.S }
            set var.dT = { global.mosSDS }

        ; Now calculate the change in velocity as a percentage
        ; of the maximum spindle speed, and multiply the dwell time
        ; by that percentage with 5% extra leeway.
        ; Ceil this so we always wait a round second, no point waiting
        ; less than 1 anyway.
        set var.dT = { ceil(var.dT * (abs(spindles[var.sID].current - param.S) / spindles[var.sID].max) * 1.05) }

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

; Wait for the spindle to change speed, if necessary,
; and display a message indicating why we're waiting
; if expert mode is turned off.
if { var.dT > 0 }
    if { !global.mosEM }
        echo { "Waiting " ^ var.dT ^ " seconds for spindle #" ^ var.sID ^ " to change speed" }
    G4 S{var.dT}