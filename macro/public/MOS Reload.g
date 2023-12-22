; MOS Reload.g
echo {"Reloading MillenniumOS..."}
if { ! global.mosExpertMode }
    M291 R"Reload MillenniumOS" P"Reload MillenniumOS ?" S3
    if result == -1
        M99
M98 P"mos.g"