; M3.9.g: SPINDLE ON, CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; It takes a bit of time to spin up the spindle. How long this
; requires depends on the VFD setup and the spindle power. The spindle
; needs to be controlled by both the firmware (for pause / resume
; amongst other things) and the post-processor, so we need an m-code
; that can be used by both and that means our wait-for-spindle dwell
; time only needs to exist in one place.
; USAGE: M3.9 [S<rpm>] [P<spindle-id>] [D<override-dwell-seconds>]

; Only warn the user if the job is not paused, pausing or resuming.
if { !global.mosEM && state.status != "resuming" && state.status != "pausing" && state.status != "paused" }
    M291 P{"<b>CAUTION</b>: Spindle will now start. Check that workpiece and tool are secure, and all safety precautions have been taken before pressing <b>Continue</b>."} R"MillenniumOS: Warning" S4 K{"Continue", "Pause"} F0
    if { input == 1 }
        M291 P{ "<b>CAUTION</b>: The job has been paused. Clicking <b>""Resume Job""</b> will start the spindle <b>INSTANTLY</b>, with no confirmation.<br/><b>BE CAREFUL!</b>" } R"MillenniumOS: Warning" S2 T0
        M25

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

if { result != 0 }
    abort {"Spindle failed to start!"}

var dwellSec = { (exists(param.D) ? param.D : global.mosSAS) }

if { var.dwellSec > 0 }
    ; Wait for spindle to accelerate
    echo { "Waiting " ^ var.dwellSec ^ " seconds for spindle to accelerate" }
    G4 S{var.dwellSec}