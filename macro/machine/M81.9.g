; M81.9.g: Allow operator to disable ATX power if configured
; USAGE: M81.9

; If no ATX power port is configured, exit
if { state.atxPowerPort == null }
    M99

; Otherwise, check the state and prompt the operator to disable ATX power
; if it is not already disabled.
if { state.atxPower }
    M291 P{"<b>CAUTION</b>: Machine Power is currently <b>activated</b>. Do you want to deactivate power to the machine?<br/>This will stop <b>ALL</b> movement and spindle activity!"} R"MillenniumOS: Safety Net" S4 K{"Deactivate", "Cancel"} F1
    if { input == 0 }
        M81
        echo {"MillenniumOS: Safety Net - Machine Power Deactivated!<br/>Run <b>M80.9</b> to activate power."}