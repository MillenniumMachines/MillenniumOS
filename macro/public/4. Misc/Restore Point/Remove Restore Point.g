; Remove Restore Point.g
;
; Remove the restore point config override file.
if { fileexists("0:/sys/config-override.g") }
    echo { "MillenniumOS: Restore point has been removed." }
    M472 P{ "0:/sys/config-override.g" }
else
    echo { "MillenniumOS: No restore point to remove." }