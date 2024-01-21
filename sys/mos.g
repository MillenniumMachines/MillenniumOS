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

; If user vars file doesn't exist, run configuration wizard
if { !fileexists("0:/sys/mos-user-vars.g") }
    echo { "No user configuration file found. Running configuration wizard." }
    G8000

if { fileexists("0:/sys/mos-user-vars.g.example") }
    echo { "Cleaning up extraneous mos-user-vars.g.example file." }
    M472 P{"0:/sys/mos-user-vars.g.example" }

M98 P{"mos-user-vars.g"}

; Sanity check and perform any loading steps
if { !exists(global.mosLoaded) }
    global mosLoaded=false
else
    set global.mosLoaded=false

M98 P"mos-boot.g"
