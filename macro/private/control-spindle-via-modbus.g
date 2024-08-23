; control-spindle-via-modbus.g
; Implements control of a Spindle over Modbus.
; It hooks the spindle details (direction, speed) and
; uses these to change the state of the spindle using
; M260.1 and M261.1 commands.

; Reset inverter
;M260.1 P1 A1 F6 R4353 B38550

;Set Frequency to 22000RPM
;M260.1 P1 A1 F6 R4098 B22000

; Run forwards
;M260.1 P1 A1 F6 R4097 B2


; It also monitors the spindle and will report

if { !exists(global.mosLdd) || !global.mosLdd }
    M99


; 0 = Status Bits, 1 = Requested Frequency, 2 = Output Frequency, 3 = Output Current, 4 = Output Voltage
M261.1 P1 A1 F3 R4097 B5 V"spindleState"

G4 P1

; Read output power
M261.1 P1 A1 F3 R4123 B1 V"spindlePower"
;2f10 0124 30ea

; Read any error codes
M261.1 P1 A1 F3 R4103 B2 V"spindleErrors"

G4 P1

; spindleState[0] is a bitmask of the following values:
; b15:during tuning
; b14: during inverter reset
; b13, b12: Reserved
; b11: inverter E0 status
; b10~8: Reserved
; b7:alarm occurred
; b6:frequency detect
; b5:Parameters reset end
; b4: overload
; b3: frequency arrive
; b2: during reverse rotation
; b1: during forward rotation
; b0: running

if { var.spindleState == null }
    M99

var shouldRun     = { spindles[0].state == "forward" || spindles[0].state == "reverse" }

set global.mosSRF = { mod(floor(var.spindleState[0]/pow(2,1)),2) == 1 }
set global.mosSRR = { mod(floor(var.spindleState[0]/pow(2,2)),2) == 1 }
set global.mosSTR = { mod(floor(var.spindleState[0]/pow(2,3)),2) == 1 }
set global.mosSR  = { global.mosSRF || global.mosSRR }
set global.mosSIF = { var.spindleState[1] }
set global.mosSOF = { var.spindleState[2] }
set global.mosSOC = { var.spindleState[3] }
set global.mosSOV = { var.spindleState[4] }
set global.mosSOP = { var.spindlePower[0] * 0.75 * 10 }
; set global.mosSOP = { (global.mosSOC * 0.01) * (global.mosSOV * 0.01) * 0.75 }

; If spindle should not run but is running, stop it,
; set the input frequency to 0 and return.
if { !var.shouldRun && global.mosSR }
    M260.1 P1 A1 F6 R4097 B0
    G4 P1
    M260.1 P1 A1 F6 R4098 B0
    set global.mosSAC = false
    M99

; Spindle acceleration is complete when STR flag is set
if { !global.mosSAC && global.mosSR && global.mosSTR }
    set global.mosSAC = true

; If spindle has accelerated but is not running, pause the job.
if { global.mosSAC && !global.mosSR }
    set global.mosSAC = false
    if { job.file.fileName != null && !(state.status == "resuming" || state.status == "pausing" || state.status == "paused") }
        echo { "Spindle has stopped unexpectedly - pausing job!" }
        M25
    else
        M99

if { global.mosSAC && !global.mosSTR }
    set global.mosSAC = false
    ; Spindle is no longer running at the target speed
    if { job.file.fileName != null && !(state.status == "resuming" || state.status == "pausing" || state.status == "paused") }
        echo { "Spindle speed is not stable at " ^ global.mosSIF ^ "RPM - pausing job!" }
        M25
    else
        M99

if { global.mosSIF != spindles[0].active }
    M260.1 P1 A1 F6 R4098 B{spindles[0].active}
    set global.mosSAC = false

G4 P1

if { spindles[0].state == "forward" && !global.mosSRF }
    M260.1 P1 A1 F6 R4097 B2
    set global.mosSAC = false

elif { spindles[0].state == "reverse" && !global.mosSRR }
    M260.1 P1 A1 F6 R4097 B4
    set global.mosSAC = false