; M8004.g: WAIT FOR GPIN STATUS CHANGE BY ID
;
; This macro is called when we expect to be able to use
; a general purpose input to register a change in state.
; We wait for the particular pin to change status.

if { !exists(param.K) || param.K < 0 || param.K >= #sensors.gpIn }
    abort { "Pin ID not specified or out of range" }

var pinId = { param.K }

; Delay between checking pin status in ms
var delay = { (exists(param.D)) ? param.D : 100 }

; Maximum time to wait without detecting a status change, in s
var maxWait = { (exists(param.W)) ? param.W : 30 }

; Calculate number of iterations to reach maxWait
; at given delay
var maxIterations = { var.maxWait / (var.delay/1000) }

; Previous pin value
var previousValue = { null }

; Loop until a pin is detected or the maximum number of iterations is reached
while { iterations < var.maxIterations }
    G4 P{ var.delay }

    ; If pin value has changed and we had a previous iteration value, treat this as a detected pin and return.
    if { sensors.gpIn[var.pinId].value != var.previousValue && var.previousValue != null }
        M99

    ; If no pin status change detected, save the current value for the next iteration
    set var.previousValue = { sensors.gpIn[var.pinId].value }

abort { "Pin " ^ var.pinId ^ " status change not detected within " ^ var.maxWait ^ "s! Aborting..."}