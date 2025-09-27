; M5.9.g: SPINDLE OFF
;
; USAGE: M5.9 [D<overrideDwellSeconds>]

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.D) && param.D < 0 }
    abort "Dwell time must be a positive value!"

; Wait for all movement to stop before continuing.
M400

; Spindles only need to be stopped if they're actually running.
var spindleID = { global.nxtSpindleID }

var doWait = false

while (iterations < #spindles) && !var.doWait
    ; Ignore unconfigured spindles
    if { spindles[iterations].state == "unconfigured" }
        continue

    set var.doWait = { spindles[iterations].current != 0 }
    ; In case M5.9 should stop a spindle that _isnt_ the one
    ; configured in NeXT. We'll calculate the delay time based
    ; on the spindle that is actually running.
    set var.spindleID = { iterations }

; Must calculate dwell time before spindle speed is changed.

; Default is to not dwell
var dwellTime = 0

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }
elif { var.doWait }
    ; Dwell time defaults to the previously timed spindle deceleration time.
    set var.dwellTime = { global.nxtSpindleDecelSec }

    ; We want to run M5 regardless of if var.spindleID is valid or not, so we check
    ; for nulls on the individual values before doing the dwellTime calculation.
    ; If the current spindle is not valid then M5 will be called but we wont
    ; wait for it to stop.
    if { spindles[var.spindleID].current != null && spindles[var.spindleID].max != null }
        set var.dwellTime = { ceil(var.dwellTime * (abs(spindles[var.spindleID].current) / spindles[var.spindleID].max) * 1.05) }

; We run M5 unconditionally for safety purposes. If
; the object model is not up to date for whatever
; reason, then this protects us from not stopping
; the spindle when the running gcode expected it to
; be stopped.
M5

; No spindles were running, so don't wait
if { !var.doWait }
    M99

; Spindle feedback functionality is now part of the 'Nice-to-Have' features and will be implemented later.

elif { var.dwellTime > 0 }
    ; Otherwise wait for spindle to stop manually
    if { !global.nxtExpertMode }
        echo { "NeXT: Waiting " ^ var.dwellTime ^ " seconds for spindle #" ^ var.spindleID ^ " to stop" }
    G4 S{var.dwellTime}
