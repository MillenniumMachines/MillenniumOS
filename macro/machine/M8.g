; M8.g: FLOOD ON
;
; Flood enables pressurised coolant flow over the cutting tool.

if { !global.mosFeatCoolantControl || global.mosCFID == null }
    echo { "MillenniumOS: Coolant Control feature is disabled or Flood Coolant not configured, cannot enable." }
    M99

; Wait for all movement to stop before continuing.
M400

; Turn on flood
M42 P{global.mosCFID} S1