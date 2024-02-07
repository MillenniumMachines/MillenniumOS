; Reload.g
if { ! global.mosExpertMode }
    M291 R"MillenniumOS: Reload" P"Reload MillenniumOS ?" S3
    if { result == -1 }
        M99
M9999