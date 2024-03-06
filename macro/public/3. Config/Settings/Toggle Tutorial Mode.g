; Toggle Tutorial Mode.g

; Toggles global.mosTM.
if { !global.mosTM }
    M291 R"MillenniumOS: Toggle Tutorial Mode" P"Enable <b>Tutorial Mode</b>?<br/>Tutorial Mode enables probing cycle guides and additional confirmation points during operations." S3
    if { result == -1 }
        M99

set global.mosTM = {!global.mosTM}

echo {"MillenniumOS: Tutorial Mode " ^ (global.mosTM ? "Enabled" : "Disabled")}