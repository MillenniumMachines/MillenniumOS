; mos.g
;
; MillenniumOS entrypoint.
;
; This file can be included at the end of RRF's config.g file using
; M98 P"mos.g"

; MOS Release version
if { exists(global.mosVer) }
    set global.mosVer = { "%%MOS_VERSION%%" }
else
    global mosVer = { "%%MOS_VERSION%%" }

; Load internal / default variables
if { !exists(global.mosVarsLoaded) }
    M98 P"mos-vars.g"
    global mosVarsLoaded=true

if { !exists(global.mosLdd) }
    global mosLdd=false
else
    set global.mosLdd=false

if { !exists(global.mosErr) }
    global mosErr=null
else
    set global.mosErr=null

; If user vars file doesn't exist, run configuration wizard
if { !fileexists("0:/sys/mos-user-vars.g") }
    echo { "No user configuration file found. Running configuration wizard." }
    G8000
    M99

; Delete extraneous example uservars
if { fileexists("0:/sys/mos-user-vars.g.example") }
    M472 P{"0:/sys/mos-user-vars.g.example" }

; Install new daemon.g. Daemon file is used to report any startup errors to
; the user on boot.
if { fileexists("0:/sys/daemon.install") }
    if { fileexists("0:/sys/daemon.g") }
        M471 S"/sys/daemon.g" T"/sys/daemon.g.old" D1
    M471 S"/sys/daemon.install" T"/sys/daemon.g"

; Load user vars
if { fileexists("0:/sys/mos-user-vars.g") }
    M98 P"mos-user-vars.g"

; Load override vars
if { fileexists("0:/sys/mos-override-vars.g") }
    M98 P"mos-override-vars.g"

; Run sanity checks and confirm boot
M98 P"mos-boot.g"

