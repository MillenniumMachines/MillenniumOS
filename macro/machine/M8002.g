; M8002.g: WAIT FOR PROBE STATUS CHANGE BY ID
;
; This macro is called when we expect to be able to use
; a touch probe, and a touch probe has not yet been assigned
; "connected". We wait for the particular probe to change status
; so that we can verify that it is connected.

if { !exists(param.K) || param.K < 0 || param.K >= #sensors.probes }
    abort { "Probe ID not specified or out of range" }

if { sensors.probes[param.K].type < 5 || sensors.probes[param.K].type > 8 }
    abort { "Probe ID is not compatible!" }

var probeId = { param.K }

; Delay between checking probe status in ms
var delay = { (exists(param.D)) ? param.D : 100 }

; Maximum time to wait without detecting a probe, in s
var maxWait = { (exists(param.W)) ? param.W : 30 }

; Calculate number of iterations to reach maxWait
; at given delay
var maxIterations = { var.maxWait / (var.delay/1000) }

; Previous probe value
var previousValue = { null }

set global.mosPD = null

; Loop until a probe is detected or the maximum number of iterations is reached
while { iterations < var.maxIterations }
    G4 P{ var.delay }

    ; If probe value has changed and we had a previous iteration value, treat this as a detected probe and return.
    if { sensors.probes[var.probeId].value[0] != var.previousValue && var.previousValue != null }
        set global.mosPD = var.probeId
        M99

    ; If no probe status change detected, save the current value for the next iteration
    set var.previousValue = { sensors.probes[var.probeId].value[0] }

; Commented due to memory limitations
; M7500 S{ "MillenniumOS: Probe " ^ var.probeId ^ " not detected after " ^ var.maxWait ^ "s" }