; mos.g
;
; MillenniumOS entrypoint.
;
; This file can be included at the end of RRF's config.g file using
; M98 P"mos.g"

; MOS Release version
if { exists(global.mosVersion) }
    set global.mosVersion="0.0.1"
else
    global mosVersion="0.0.1"

; Load internal / default variables
if { !exists(global.mosVarsLoaded) }
    M98 P"mos-vars.g"
    global mosVarsLoaded=true

if { !exists(global.mosLoaded) }
    global mosLoaded=false
else
    set global.mosLoaded=false

if { !exists(global.mosStartupError) }
    global mosStartupError=null
else
    set global.mosStartupError=null

; If user vars file doesn't exist, run configuration wizard
if { !fileexists("0:/sys/mos-user-vars.g") }
    echo { "No user configuration file found. Running configuration wizard." }
    G8000

if { fileexists("0:/sys/mos-user-vars.g.example") }
    echo { "Cleaning up extraneous mos-user-vars.g.example file." }
    M472 P{"0:/sys/mos-user-vars.g.example" }

; Install new daemon.g. Daemon file is used to report any startup errors to
; the user on boot.
if { fileexists("0:/sys/daemon.install") }
    echo { "MillenniumOS: Installing new daemon.g..." }
    if { fileexists("0:/sys/daemon.g") }
        M471 S"/sys/daemon.g" T"/sys/daemon.g.old" D1
    M471 S"/sys/daemon.install" T"/sys/daemon.g"

M98 P"mos-user-vars.g"
M98 P"mos-boot.g"
