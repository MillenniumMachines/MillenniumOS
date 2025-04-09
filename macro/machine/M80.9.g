; M80.9.g: Allow operator to enable ATX power on boot if configured
; USAGE: M80.9

; If no ATX power port is configured, exit
if { state.atxPowerPort == null }
    M99

; Otherwise, check the state and prompt the operator to enable ATX power
; if it is not already enabled.
if { !state.atxPower }
    M291 P{"<b>CAUTION</b>: Machine Power is currently <b>deactivated</b>. Do you want to activate power to the machine?<br/>Check the machine is in a safe state before pressing <b>Activate</b>!"} R"MillenniumOS: Safety Net" S4 K{"Activate", "Cancel"} F1
    if { input == 0 }
        M80
        echo {"MillenniumOS: Safety Net - Machine Power Activated!<br/>Run <b>M81.9</b> to deactivate power."}
