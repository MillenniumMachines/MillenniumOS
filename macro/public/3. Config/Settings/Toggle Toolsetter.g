; Toggle Toolsetter.g

if { global.mosFeatToolSetter }
    M291 R"MillenniumOS: Toggle Toolsetter" P"Disable Toolsetter? You will be asked to reset the origin in Z after each tool change!" S3
    if { result == -1 }
        M99

if { global.mosTSID == null || global.mosTSP == null }
    M291 R"MillenniumOS: Toggle Toolsetter" P"Toolsetter has not been configured. Please configure the toolsetter using the Configuration Wizard first." S2
    M99

set global.mosFeatToolSetter = {!global.mosFeatToolSetter}

echo {"MillenniumOS: Toolsetter " ^ (global.mosFeatToolSetter ? "Enabled" : "Disabled")}