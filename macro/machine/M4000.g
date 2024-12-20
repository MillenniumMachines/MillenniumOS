; M4000.g: DEFINE TOOL
;
; Defines a tool by index.

; We create an RRF tool and link it to the managed spindle.

; Given that RRF tracks limited information about tools, we store our own global variable
; containing tool information that is useful for our purposes. This includes tool radius,
; deflection values in X and Y (for probe tools), and more in future.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.P) || !exists(param.R) || !exists(param.S) }
    abort { "Must provide tool number (P...), radius (R...) and description (S...) to register tool!" }

if { #param.S < 1 }
    abort { "Tool description must be at least 1 character long!" }

; Validate tool index
if { param.P >= limits.tools || param.P < 0 }
    abort { "Tool index must be between 0 and " ^ limits.tools-1 ^ "!" }

; Check if tool is already defined and matches. If so, skip adding it.
; This allows us to re-run a file that defines the tool that is currently
; loaded, without unloading the tool.
; This has to be split over multiple lines due to length of the condition.
; Make sure to check that the tool table has enough entries.

; Initial tool similarity check - make sure the tool is defined in both the internal
; RRF tool table and our own mosTT table.
var toolSame = { global.mosTT[param.P] != null && #tools > param.P && tools[param.P] != null }

; Check that tool radius and spindle match
set var.toolSame = { var.toolSame && global.mosTT[param.P][0] == param.R && tools[param.P].spindle == ((exists(param.I)) ? param.I : global.mosSID) }

; Check that tool description matches
set var.toolSame = { var.toolSame && tools[param.P].name == param.S }

; Check that deflection values match
set var.toolSame = { var.toolSame && exists(param.X) && global.mosTT[param.P][1][0] == param.X }
set var.toolSame = { var.toolSame && exists(param.Y) && global.mosTT[param.P][1][1] == param.Y }

; If the tool already matches, return.
if { var.toolSame }
    M99

; Define RRF tool against spindle.
; Allow spindle ID to be overridden where necessary using I parameter.
; This is mainly used during the configuration wizard.
M563 P{param.P} S{param.S} R{(exists(param.I)) ? param.I : global.mosSID}

; Store tool details in zero-indexed array.
set global.mosTT[param.P] = { global.mosET }

; Set tool radius
set global.mosTT[param.P][0] = { param.R }

; If X and Y parameters are given, these are deemed to be
; the deflection distance of the tool in the relevant axis
; when used for probing. This does not need to be set for
; non-probe tools.
if { exists(param.X) }
    set global.mosTT[param.P][1][0] = { param.X }

if { exists(param.Y) }
    set global.mosTT[param.P][1][1] = { param.Y }

; Commented due to memory limitations
; M7500 S{"Stored tool #" ^ param.P ^ " R=" ^ param.R ^ " S=" ^ param.S}