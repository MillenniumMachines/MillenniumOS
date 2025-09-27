; M9.g: CONTROL ALL COOLANTS
;
; By default, disables all possible Coolant Outputs.
; If called with R1, restores the previous state of the
; coolant outputs. The state is only saved on pause.

; Do not report an error here as M9 is called during parking
if { !global.nxtFeatureCoolantControl }
    M99

; Wait for all movement to stop before continuing.
M400

; Restore previous state if requested
var restore = { exists(param.R) && param.R == 1 }

; Configure flood
if { global.nxtCoolantFloodID != null }
    M42 P{global.nxtCoolantFloodID} S{ var.restore ? global.nxtPinStates[global.nxtCoolantFloodID] : 0 }

; Configure mist
if { global.nxtCoolantMistID != null }
    M42 P{global.nxtCoolantMistID} S{ var.restore ? global.nxtPinStates[global.nxtCoolantMistID] : 0 }

; Configure air blast
if { global.nxtCoolantAirID != null }
    M42 P{global.nxtCoolantAirID} S{ var.restore ? global.nxtPinStates[global.nxtCoolantAirID] : 0 }
