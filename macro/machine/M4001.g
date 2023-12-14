; M4001.g
; Removes a tool by index

; Read tool number to remove
if { !exists(param.I) }
    abort "Must provide tool number (I...) to remove from tool list!"

if { param.I > #global.toolTable }
    abort { "Tool index must be less than or equal to " ^  #global.toolTable ^ "!" }

; Store tool description in zero-indexed
; Array.
set global.toolTable[param.I-1] = {"", 0}

echo {"Removed tool #" ^ param.I}