; M4001.g: REMOVE TOOL
;
; Removes a tool by index

; Read tool number to remove
if { !exists(param.P) }
    abort "Must provide tool number (P...) to remove from tool list!"

if { param.P >= limits.tools || param.P < 1 }
    abort { "Tool index must be between 1 and " ^  limits.tools-1 ^ "!" }

; Reset RRF Tool
M563 P{param.P} R-1

; Reset tool description in zero-indexed array
set global.mosToolTable[param.P] = {0.0, false, {0, 0}}

echo {"Removed tool #" ^ param.P}