; M4001.g: REMOVE TOOL
;
; Removes a tool by index

; Read tool number to remove
if { !exists(param.P) }
    abort "Must provide tool number (P...) to remove from tool list!"

; Before any tools are defined, the tool table is empty.
if { #tools < 1 }
    M99

var maxTools = { limits.tools-1 }

if { param.P > var.maxTools || param.P < 0 }
    abort { "Tool index must be between 0 and " ^  var.maxTools ^ "!" }

; Check if the tool exists
if { tools[param.P] == null }
    M99

; Reset RRF Tool
M563 P{param.P} R-1 S"Unknown Tool"

; Reset tool description in zero-indexed array
set global.mosToolTable[param.P] = global.mosEmptyTool

M7500 S{"Removed tool #" ^ param.P}