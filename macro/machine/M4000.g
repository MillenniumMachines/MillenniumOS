; M4000.g
; Defines a tool by index.

; In combination with T<N> M6, we can prompt users to change using
; a user-friendly process.

if { !exists(param.I) || !exists(param.R) || !exists(param.N) }
    abort "Must provide tool number (I...), radius (R...) and name (N\"..."\) to register tool!"

if { param.I > #global.toolTable }
    abort { "Tool index must be less than or equal to " ^  #global.toolTable ^ "!" }

; Store tool description in zero-indexed array.
set global.toolTable[param.I-1] = {param.R, param.N}

echo {"Stored tool #" ^ param.I ^ ": " ^ param.N ^ " R=" ^ param.R }