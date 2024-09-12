; M4001.g: REMOVE TOOL
;
; Removes a tool by index

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Read tool number to remove
if { !exists(param.P) }
    abort "Must provide tool number (P...) to remove from tool list!"

if { param.P >= limits.tools || param.P < 0 }
    abort { "Tool index must be between 0 and " ^ (limits.tools-1) ^ "!" }

; Before any tools are defined, the tool table is empty.
; Abort, because we cannot check existence of any tools.
if { #tools < 1 }
    M99

; Check if the tool exists
; The tool array is lazily-extended by RRF, so if the
; number of tools is less than the requested tool number
; then the tool cannot exist.
if { #tools < param.P || tools[param.P] == null }
    M99

; Reset RRF Tool
M563 P{param.P} R-1 S"Unknown Tool"

; Reset tool details in zero-indexed array
set global.mosTT[param.P] = { global.mosET }

; Commented due to memory limitations
; M7500 S{"Removed tool #" ^ param.P}