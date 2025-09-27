; M81.9.g: DISABLE ATX POWER
;
; Allows the operator to disable ATX power with confirmation.
;
; USAGE: M81.9

; If no ATX power port is configured, exit
if { state.atxPowerPort == null }
    M99

; If power is already disabled, exit
if { !state.atxPower }
    M99

; Prompt the operator to disable ATX power
if { global.nxtUiReady }
    M1000 P{"<b>CAUTION</b>: Machine Power is currently <b>activated</b>. Do you want to deactivate power to the machine?<br/>This will stop <b>ALL</b> movement and spindle activity!"} R"NeXT: Safety Net" K{"Deactivate", "Cancel"} F1
else
    M291 P{"<b>CAUTION</b>: Machine Power is currently <b>activated</b>. Do you want to deactivate power to the machine?<br/>This will stop <b>ALL</b> movement and spindle activity!"} R"NeXT: Safety Net" S4 K{"Deactivate", "Cancel"} F1

if { input == 0 }
    M81
    echo {"NeXT: Safety Net - Machine Power Deactivated!<br/>Run <b>M80.9</b> to activate power."}