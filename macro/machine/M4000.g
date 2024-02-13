; M4000.g: DEFINE TOOL
;
; Defines a tool by index.

; We create an RRF tool and link it to the managed spindle.

; Given that RRF tracks limited information about tools, we store our own global variable
; containing tool information that may be useful in future (tool radius, coordinate offsets
; for automatic tool-changing etc)

if { !exists(param.P) || !exists(param.R) || !exists(param.S) }
    abort { "Must provide tool number (P...), radius (R...) and description (S...) to register tool!" }

var maxTools = { limits.tools-1 }

; Validate tool index
if { param.P > var.maxTools || param.P < 0 }
    abort { "Tool index must be between 0 and " ^  var.maxTools ^ "!" }

; Check if tool already exists. If no tools are defined, the
; length of the tools array is 0.
if { #tools > 0 && tools[param.P].spindle != -1 }
    abort { "Tool #" ^ param.P ^ " is already defined." }

; Define RRF tool against spindle.
; Allow spindle ID to be overridden where necessary using I parameter.
M563 P{param.P} S{param.S} R{(exists(param.I)) ? param.I : global.mosSpindleID}

; Store tool description in zero-indexed array.
set global.mosToolTable[param.P] = { global.mosEmptyTool }

; Set tool radius
set global.mosToolTable[param.P][0] = { param.R }

M7500 S{"Stored tool #" ^ param.P ^ " R=" ^ param.R ^ " S=" ^ param.S}