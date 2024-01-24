; M4000.g: DEFINE TOOL
;
; Defines a tool by index.

; We create an RRF tool and link it to the managed spindle.

; Given that RRF tracks limited information about tools, we store our own global variable
; containing tool information that may be useful in future (tool radius, coordinate offsets
; for automatic tool-changing etc)

if { !exists(param.P) || !exists(param.R) || !exists(param.S) }
    abort { "Must provide tool number (P...), radius (R...) and description (S...) to register tool!" }

if { param.P >= limits.tools || param.P < 1 }
    abort { "Tool index must be between 1 and " ^  limits.tools-1 ^ "!" }

; Define RRF tool against spindle.
; RRF Tools are zero-indexed so we can store 1 less than RRF.
M563 P{param.P} S{param.S} R{global.mosSpindleID}

; Store tool description in zero-indexed array.
set global.mosToolTable[param.P] = {param.R, false, {0, 0}}

echo {"Stored tool #" ^ param.P ^ ": " ^ param.S ^ " R=" ^ param.R }