; M4000.g
; Defines a tool by index.

; In combination with T<N> M6, we can prompt users to change using
; a user-friendly process.

if { !exists(param.I) || !exists(param.R) || !exists(param.N) }
    abort "Must provide tool number (I...), radius (R...) and name (N\"..."\) to register tool!"

var toolID = param.I
var toolName = param.N
var toolRadius = param.R
if { var.toolID > #global.toolTable }
    abort { "Tool index must be less than or equal to " ^  #global.toolTable ^ "!" }

; Store tool description in zero-indexed
; Array.
set global.toolTable[var.toolID-1] = {var.toolRadius, var.toolName}

echo {"Stored tool #" ^ var.toolID ^ ": " ^ var.toolName ^ " R=" ^ var.toolRadius }