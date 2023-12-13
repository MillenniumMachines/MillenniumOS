; M4001.g
; Removes a tool by index

; Read tool number to remove
if { !exists(param.I) }
    abort "Must provide tool number (I...) to remove from tool list!"

var toolID = param.I

if { var.toolID > #global.toolTable }
    abort { "Tool index must be less than or equal to " ^  #global.toolTable ^ "!" }

; Store tool description in zero-indexed
; Array.
set global.toolTable[var.toolID-1] = {"", 0}

M118 P0 L2 S{"Removed tool #" ^ var.toolID}