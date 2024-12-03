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

; Wait for all movement to stop before continuing.
M400

; Spindles only need to be stopped if they're actually running.
; The base M5 code will stop the spindle for the current tool, or
; all spindles if no tool is selected. To avoid having to wait the
; deceleration time if no spindles are actually running, we check
; for this first and only trigger a wait if any spindles are
; activated.
var sID = { global.mosSID }

var doWait = false

while { (iterations < #spindles) && !var.doWait }
    ; Ignore unconfigured spindles
    if { spindles[iterations].state == "unconfigured" }
        continue

    set var.doWait = { spindles[iterations].current != 0 }
    ; In case M5.9 should stop a spindle that _isnt_ the one
    ; configured in MOS. We'll calculate the delay time based
    ; on the spindle that is actually running.
    set var.sID = { iterations }

; Must calculate dwell time before spindle speed is changed.

; Default is to not dwell
var dwellTime = 0

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }
elif { var.doWait }
    ; Dwell time defaults to the previously timed spindle deceleration time.
    set var.dwellTime = { global.mosSDS }

    ; Now calculate the change in velocity as a percentage
    ; of the maximum spindle speed, and multiply the dwell time
    ; by that percentage with 5% extra leeway.
    ; Ceil this so we always wait a round second, no point waiting
    ; less than 1 anyway.

    ; We want to run M5 regardless of if var.sID is valid or not, so we check
    ; for nulls on the individual values before doing the dwellTime calculation.
    ; If the current spindle is not valid then M5 will be called but we wont
    ; wait for it to stop.
    if { spindles[var.sID].current != null && spindles[var.sID].max != null }
        set var.dwellTime = { ceil(var.dwellTime * (abs(spindles[var.sID].current) / spindles[var.sID].max) * 1.05) }

; We run M5 unconditionally for safety purposes. If
; the object model is not up to date for whatever
; reason, then this protects us from not stopping
; the spindle when the running gcode expected it to
; be stopped.
M5

; No spindles were running, so don't wait
if { !var.doWait }
    M99

if { global.mosFeatSpindleFeedback && global.mosSFSID != null }
    if { !global.mosEM }
        echo { "MillenniumOS: Waiting for spindle #" ^ var.sID ^ " to stop" }
    ; Wait for Spindle Feedback input to change state.
    ; Wait a maximum of 30 seconds, or abort.
    M8004 K{global.mosSFSID} D100 W30

elif { var.dwellTime > 0 }
    ; Otherwise wait for spindle to stop manually
    if { !global.mosEM }
        echo { "MillenniumOS: Waiting " ^ var.dwellTime ^ " seconds for spindle #" ^ var.sID ^ " to stop" }
    G4 S{var.dwellTime}
