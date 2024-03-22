; M7500.g: EMIT DEBUG MESSAGE
;
; This is designed for internal use, so will not
; print an error or warning if called incorrectly.
; When debug mode is enabled, calls to this macro
; will emit a message to the console.
;
; Usage: M7500 S"message"

if { !inputs[state.thisInput].active }
    M99

if { global.mosDebug }
    if { !exists(param.S)}
        M99
    echo {"[DEBUG]: " ^ param.S}