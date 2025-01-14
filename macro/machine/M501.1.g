; M501.1.g: Load restorable settings or discard restore point
;
; USAGE: M501.1

var restoreFile = { "mos-restore-point.g" }
var delete = { exists(param.D) && param.D == 1 }

if { fileexists("0:/sys/" ^ var.restoreFile) }
    if { !var.delete }
        M291 P{"<b>Restore point found.</b><br/>Click <b>Load</b> to restore saved WCS and Tool details or <b>Discard</b> to delete the restore point."} R"MillenniumOS: Restore Point" T0 S4 K{"Load", "Discard"} F0
        if { input == 0 }
            M98 P{ var.restoreFile }
            M291 P{"Restore point loaded. Please check the selected WCS, loaded tool and WCS origins <b>CAREFULLY</b> before continuing!"} R"MillenniumOS: Restore Point" S2 T0
            M99

    M471 S{"/sys/" ^ var.restoreFile } T{"/sys/" ^ var.restoreFile ^ ".bak"} D1
    echo { "MillenniumOS: Restore point has been backed up to "  ^ var.restoreFile ^ ".bak before being discarded. It will be deleted when you next discard a restore point!" }
else
    echo { "MillenniumOS: No restore point found" }