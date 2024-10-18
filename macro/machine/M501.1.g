; M501.1.g: Load restorable settings from config-override.g
;
; USAGE: M501.1

if { fileexists("0:/sys/config-override.g") }
    M291 P{"Restore point containing WCS or Tool settings found.<br/>Click <b>Load</b> to restore from this point or <b>Reset</b> to delete it."} R"MillenniumOS: Restore Point" T0 S4 K{"Load", "Reset"} F0
    if { input == 0 }
        M98 P{ "config-override.g" }
        M291 P{"Restore point loaded. Please check the selected WCS, loaded tool and WCS origins <b>CAREFULLY</b> before continuing!"} R"MillenniumOS: Restore Point" S2 T0
    else
        echo { "MillenniumOS: Restore point has been discarded." }
        M472 P{ "0:/sys/config-override.g" }
