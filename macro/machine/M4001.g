; M4001.g: REMOVE TOOL
;
; Removes a tool by index

; Read tool number to remove
if { !exists(param.P) }
    abort "Must provide tool number (P...) to remove from tool list!"

var maxTools = { limits.tools-1 }

; If enabled, touch probe is configured
; in the last tool slot.
if { global.mosTouchProbeToolID != null }
    set var.maxTools = { var.maxTools-1 }

if { param.P > var.maxTools || param.P < 0 }
    abort { "Tool index must be between 1 and " ^  var.maxTools ^ "!" }

; Reset RRF Tool
M563 P{param.P} R-1 S"Unknown Tool"

; Reset tool description in zero-indexed array
set global.mosToolTable[param.P] = {0.0, false, {0, 0}}

echo {"Removed tool #" ^ param.P}