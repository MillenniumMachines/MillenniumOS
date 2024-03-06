; Reload.g
if { ! global.mosEM }
    M291 R"MillenniumOS: Reload" P"Reload MillenniumOS?<br/><b>NOTE</b>: After uploading a new release of MillenniumOS you <b>MUST</b> restart your mainboard (M999) - reloading is not sufficient." S3
    if { result == -1 }
        M99
M9999