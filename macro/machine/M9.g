; M9.g: CONTROL ALL COOLANTS
;
; By default, disables all possible Coolant Outputs.
; If called with R1, restores the previous state of the
; coolant outputs. The state is only saved on pause.

; Do not report an error here as M9 is called during parking
if { !global.mosFeatCoolantControl }
    M99

; Wait for all movement to stop before continuing.
M400

; Restore previous state if requested
var restore = { exists(param.R) && param.R == 1 }

; Configure flood
if { global.mosCFID != null }
    M42 P{global.mosCFID} S{ var.restore ? global.mosPS[global.mosCFID] : 0 }

; Configure mist
if { global.mosCMID != null }
    M42 P{global.mosCMID} S{ var.restore ? global.mosPS[global.mosCMID] : 0 }

; Configure air blast
if { global.mosCAID != null }
    M42 P{global.mosCAID} S{ var.restore ? global.mosPS[global.mosCAID] : 0 }