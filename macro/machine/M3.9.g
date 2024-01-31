; M3.9.g: SPINDLE ON, CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; It takes a bit of time to spin up the spindle. How long this
; requires depends on the VFD setup and the spindle power. The spindle
; needs to be controlled by both the firmware (for pause / resume
; amongst other things) and the post-processor, so we need an m-code
; that can be used by both and that means our wait-for-spindle dwell
; time only needs to exist in one place.
; USAGE: M3.9 [S<rpm>] [P<spindle-id>] [D<override-dwell-seconds>]

if { !global.mosExpertMode }
    M291 P{"<b>CAUTION</b>: We will now start the spindle. Check that your workpiece and tool are secure, step away from the machine and <b>don your eye protection</b> or shut your enclosure door before pressing <b>OK</b>."} R"MillenniumOS: Warning" S3 T0

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
    M99

var dwellSeconds = { (exists(param.D) ? param.D : global.mosSpindleAccelSeconds) }

if { var.dwellSeconds > 0 }
    ; Wait for spindle to accelerate
    echo { "Waiting " ^ var.dwellSeconds ^ " seconds for spindle to accelerate" }
    G4 S{var.dwellSeconds}