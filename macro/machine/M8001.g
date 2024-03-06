; M8001.g: DETECT PROBE BY STATUS CHANGE
;
; This macro is called by the MillenniumOS configuration wizard to detect
; a change in the status of any of the configured probes. It is used to
; determine which configured probe the user wants to use as the touch probe
; or toolsetter.

; Reset detected probe ID
set global.mosDPID = null

; Delay between checking probe status in ms
var delay = { (exists(param.D)) ? param.D : 100 }

; Maximum time to wait without detecting a probe, in s
var maxWait = { (exists(param.W)) ? param.W : 30 }

; Calculate number of iterations to reach maxWait
; at given delay
var maxIterations = { var.maxWait / (var.delay/1000) }

; Generate vector of previous values for each probe
var previousValues = { vector(#sensors.probes, null) }

; Loop until a probe status change is detected or the maximum number
; of iterations is reached.
while { iterations < var.maxIterations && global.mosDPID == null }
    G4 P{ var.delay }

    ; Loop through all configured probes
    while { iterations < #sensors.probes }
        ; Skip non-existent probes or incompatible probe types
        if { sensors.probes[iterations] == null || sensors.probes[iterations].type < 5 || sensors.probes[iterations].type > 8 }
            continue

        ; If probe value has changed and we had a previous iteration value, treat this as a detected probe and return.
        if { sensors.probes[iterations].value[0] != var.previousValues[iterations] && var.previousValues[iterations] != null }
            set global.mosDPID = iterations
            break

        ; If no probe status change detected, save the current value for the next iteration
        set var.previousValues[iterations] = { sensors.probes[iterations].value[0] }
