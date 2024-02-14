; Toggle Tutorial Mode.g

; Toggles global.mosTutorialMode.
if { !global.mosTutorialMode }
    M291 R"MillenniumOS: Toggle Tutorial Mode" P"Enable <b>Tutorial Mode</b>?<br/>Tutorial Mode enables probing cycle guides and additional confirmation points during operations." S3
    if { result == -1 }
        M99

set global.mosTutorialMode = {!global.mosTutorialMode}

echo {"MillenniumOS: Tutorial Mode " ^ (global.mosTutorialMode ? "Enabled" : "Disabled")}