; M5.9.g: SPINDLE OFF
;
; It takes a bit of time to decelerate the spindle. How long this
; requires depends on the VFD setup and how much energy can be
; dissipated. A short deceleration time can be achieved through the
; use of a suitable braking resistor connected to the VFD. The spindle
; needs to be controlled by both the firmware (for pause / resume
; amongst other things) and the post-processor, so we need an m-code
; that can be used by both and that means our wait-for-spindle dwell
; time only needs to exist in one place.
; USAGE: M5.9 [D<override-dwell-seconds>]

; Spindles only need to be stopped if they're actually running.
; The base M5 code will stop the spindle for the current tool, or
; all spindles if no tool is selected. To avoid having to wait the
; deceleration time if no spindles are actually running, we check
; for this first and only trigger a wait if any spindles are
; activated.
var doWait = false
while { iterations < #spindles }
    var sS = { spindles[iterations].state }
    set var.doWait = { (var.sS != "unconfigured" && var.sS != "stopped") || var.doWait }

; We run M5 unconditionally for safety purposes. If
; the object model is not up to date for whatever
; reason, then this protects us from not stopping
; the spindle when the running gcode expected it to
; be stopped.
M5

var dwellSeconds = { (exists(param.D) ? param.D : global.mosSpindleDecelSeconds) }

if { var.doWait && var.dwellSeconds > 0 }
    ; Wait for spindle to accelerate
    echo { "Waiting " ^ var.dwellSeconds ^ " seconds for spindle to stop" }
    G4 S{var.dwellSeconds}
