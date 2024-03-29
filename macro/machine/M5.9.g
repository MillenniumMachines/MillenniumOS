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

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.D) && param.D < 0 }
    abort { "Dwell time must be a positive value!" }

; Spindles only need to be stopped if they're actually running.
; The base M5 code will stop the spindle for the current tool, or
; all spindles if no tool is selected. To avoid having to wait the
; deceleration time if no spindles are actually running, we check
; for this first and only trigger a wait if any spindles are
; activated.
var sID = { global.mosSID }
var dW = false

while { (iterations < #spindles) && !var.dW }
    set var.dW = { spindles[iterations].current != 0 }
    ; In case M5.9 should stop a spindle that _isnt_ the one
    ; configured in MOS. We'll calculate the delay time based
    ; on the spindle that is actually running.
    set var.sID = { iterations }

; Must calculate dwell time before spindle speed is changed.

; Default is to not dwell
var dT = 0

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dT = { param.D }
elif { var.dW }
    ; Dwell time defaults to the previously timed spindle deceleration time.
    set var.dT = { global.mosSDS }

    ; Now calculate the change in velocity as a percentage
    ; of the maximum spindle speed, and multiply the dwell time
    ; by that percentage with 5% extra leeway.
    ; Ceil this so we always wait a round second, no point waiting
    ; less than 1 anyway.
    set var.dT = { ceil(var.dT * (abs(spindles[var.sID].current) / spindles[var.sID].max) * 1.05) }

; We run M5 unconditionally for safety purposes. If
; the object model is not up to date for whatever
; reason, then this protects us from not stopping
; the spindle when the running gcode expected it to
; be stopped.
M5

; Wait for the spindles to stop, if necessary
if { var.dT > 0 }
    if { !global.mosEM }
        echo { "Waiting " ^ var.dT ^ " seconds for spindle #" ^ var.sID ^ " to stop" }
    G4 S{var.dT}
