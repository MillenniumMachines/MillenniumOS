; G37.g: TOOL LENGTH PROBE
;
; Measures tool length using the toolsetter.
;
; USAGE: G37
;
; Assumes tool is installed and toolsetter is configured.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate toolsetter
if { global.nxtToolSetterPos == null }
    abort "G37: Toolsetter position not configured"

; Assume toolsetter probe ID is 0 or something; adjust as needed
var probeID = {0}  ; TODO: make configurable

; Move to toolsetter XY position
G53 G0 X{global.nxtToolSetterPos[0]} Y{global.nxtToolSetterPos[1]}

; Move down to safe Z above toolsetter
G53 G0 Z{global.nxtToolSetterPos[2] + 10}  ; 10mm above

; Probe down to toolsetter
G6512 Z{global.nxtToolSetterPos[2]} I{var.probeID}

; The result is in nxtLastProbeResult
; This would be the tool length or used to set offset

echo "G37: Tool probed at Z=" ^ global.nxtLastProbeResult