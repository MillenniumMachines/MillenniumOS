; M4001.g: REMOVE TOOL
;
; Removes a tool by index

; Read tool number to remove
if { !exists(param.I) }
    abort "Must provide tool number (I...) to remove from tool list!"

if { param.I > #global.mosToolTable }
    abort { "Tool index must be less than or equal to " ^  #global.mosToolTable ^ "!" }

; Reset tool description in zero-indexed array
set global.mosToolTable[param.I-1] = {"Unknown Tool", 0.0, false, {0, 0}}

echo {"Removed tool #" ^ param.I}