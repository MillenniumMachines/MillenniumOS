; M3.1.g: SPINDLE ON, CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; It takes a bit of time to spin up the spindle. How long this
; requires depends on the VFD setup and the spindle power. The spindle
; needs to be controlled by both the firmware (for pause / resume
; amongst other things) and the post-processor, so we need an m-code
; that can be used by both and that means our wait-for-spindle dwell
; time only needs to exist in one place.
; USAGE: M3.1 [S<rpm>] [P<spindle-id>] [D<override-dwell-seconds>]
M3 {param.S} {param.P}

var dwellSeconds = { (exists(param.D) ? param.D : global.mosSpindleAccelSeconds }

if { var.dwellSeconds > 0 }
    ; Wait for spindle to accelerate
    echo { "Waiting " ^ var.dwellSeconds ^ " seconds for spindle to accelerate" }
    G4 S{var.dwellSeconds}