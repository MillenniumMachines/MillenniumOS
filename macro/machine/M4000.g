; M4000.g: DEFINE TOOL
;
; Defines a tool by index.

; These tool identifiers are tracked globally, and are used during
; tool changes to guide the user.

; We also track a tool radius, which can be used to offset-probe tools
; that have a radius larger than the toolsetter.

if { !exists(param.I) || !exists(param.R) || !exists(param.S) }
    abort "Must provide tool number (I...), radius (R...) and description (S\"..."\) to register tool!"

if { param.I > #global.mosToolTable }
    abort { "Tool index must be less than or equal to " ^  #global.mosToolTable ^ "!" }

; Store tool description in zero-indexed array.
set global.mosToolTable[param.I-1] = {param.N, param.R, false, {0, 0}}

echo {"Stored tool #" ^ param.I ^ ": " ^ param.R ^ " R=" ^ param.R }