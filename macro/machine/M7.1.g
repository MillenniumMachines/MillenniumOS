; M7.1.g: AIR BLAST ON
;
; Enables air blast for chip clearing.

if { !global.mosFeatCoolantControl || global.mosCAID == null }
    echo { "MillenniumOS: Coolant Control feature is disabled or not configured, cannot enable Air Blast." }
    M99

; Wait for all movement to stop before continuing.
M400

; Turn on air blast
M42 P{global.mosCAID} S1