; M80.9.g: ENABLE ATX POWER
;
; Allows the operator to enable ATX power with confirmation.
;
; USAGE: M80.9

; If no ATX power port is configured, exit
if { state.atxPowerPort == null }
    M99

; If power is already enabled, exit
if { state.atxPower }
    M99

; Prompt the operator to enable ATX power
if { global.nxtUiReady }
    M1000 P{"<b>CAUTION</b>: Machine Power is currently <b>deactivated</b>. Do you want to activate power to the machine?<br/>Check the machine is in a safe state before pressing <b>Activate</b>!"} R"NeXT: Safety Net" K{"Activate", "Cancel"} F1
else
    M291 P{"<b>CAUTION</b>: Machine Power is currently <b>deactivated</b>. Do you want to activate power to the machine?<br/>Check the machine is in a safe state before pressing <b>Activate</b>!"} R"NeXT: Safety Net" S4 K{"Activate", "Cancel"} F1

if { input == 0 }
    M80
    echo {"NeXT: Safety Net - Machine Power Activated!<br/>Run <b>M81.9</b> to deactivate power."}