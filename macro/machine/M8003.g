; M8004.g: LIST CHANGED GPIN PINS SINCE LAST CALL
;
; This macro is called when we expect to be able to use
; a general purpose input to register a change in state.
; We detect which pins have changed value since the previous
; call to this macro.

if { !exists(global.mosGPD) }
    global mosGPD = null

if { !exists(global.mosGPV) }
    global mosGPV = null

if { global.mosGPD == null || #global.mosGPD != #sensors.gpIn }
    set global.mosGPD = { vector(#sensors.gpIn, false) }
    set global.mosGPV = { vector(#sensors.gpIn, null) }

; Loop until a pin is detected or the maximum number of iterations is reached
while { iterations < #sensors.gpIn }
    if { global.mosGPV[iterations] != null && global.mosGPV[iterations] != sensors.gpIn[iterations].value }
        set global.mosGPD[iterations] = true
        echo { "Pin #" ^ iterations ^ " changed state since last execution" }

    set global.mosGPV[iterations] = sensors.gpIn[iterations].value