; nxt.g
; NeXT Entrypoint
; To be called from config.g using M98 P"macros/system/nxt.g"

; Set NeXT Version
if !exists(global.nxtVer)
    global nxtVer = "%%NXT_VERSION%%"
else
    set global.nxtVer = "%%NXT_VERSION%%"

; Load default variables
M98 P"macros/system/nxt-vars.g"

; Load user-defined variables if they exist
if fileexists("0:/sys/nxt-user-vars.g")
    M98 P"nxt-user-vars.g"
else
    ; In the future, the UI will handle this. For now, we halt.
    echo "ERROR: nxt-user-vars.g not found. NeXT requires configuration."
    M99

; Run boot-time sanity checks
M98 P"macros/system/nxt-boot.g"

; Final check if NeXT loaded successfully
if global.nxtLdd
    echo "NeXT v" ^ global.nxtVer ^ " loaded successfully."
else
    echo "FATAL: NeXT failed to load. Error: " ^ global.nxtErr
