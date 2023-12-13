; mos.g
;
; MillenniumOS entrypoint.
;
; This file can be included at the end of RRF's config.g file using
; M98 P"mos.g"

; MOS Release version
global.millenniumOSVersion=0.0.1

; Load internal / default variables
M98 P"mos-vars.g"

; Load user-defined variables
M98 P"mos-user-vars.g"

; Sanity check and perform any loading steps
M98 P"mos-boot.g"
