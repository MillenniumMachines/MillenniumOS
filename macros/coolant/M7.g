; M7.g: MIST ON
;
; Mist is a combination output of air and unpressurized coolant.
; Turn on the blast air first, then turn on the coolant.

if !global.nxtFeatureCoolantControl || global.nxtCoolantMistID == null
    echo "NeXT: Coolant Control feature is disabled or not configured, cannot enable Mist Coolant."
    M99

; Wait for all movement to stop before continuing.
M400

; Turn on air if not already on
M98 P"macros/coolant/M7.1.g"

; Turn on mist
M42 P{global.nxtCoolantMistID} S1
