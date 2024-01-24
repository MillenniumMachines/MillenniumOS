; G37.g: TOOL LENGTH PROBE: EXECUTE

; Probe the current tool length and save its offset.
;
; Tool length is relative to a reference surface. In this
; case, it is the Z height at which the toolsetter is activated
; by the nose of the spindle without any tool or collet in it.

; We calculate the offset based on the height of the
; toolsetter, and its' offset to the material surface
; we're working with.
;
; Operators _must_ call G6013 before this macro,
; as the reference surface must be probed with a touch
; probe, which will interfere with the tool changing
; process.
; You should call G6013 in the preamble of your gcode
; file, if you are expecting to have to change tools.
;
;
; USAGE: "G37"
;
; NOTE: This is designed to work with a NEGATIVE Z - that is, MAX is 0 and MIN is -<something>

G27 Z1    ; park spindle

if { state.status == "paused" }
    M291 P{"Cannot run G37 while paused due to safety concerns around resume positions ignoring axis limits."} R"MillenniumOS: Tool Change" S3
    M99

; Offsets are calculated based on our mosToolSetterPos[2] which
; is the activation point of the toolsetter with a dowel installed.
; Due to the Z movement limits of the machine, the installed dowel
; will need to have ~15-20mm of stickout to be able to reach the
; reference surface.

; All tool length offsets are relative to this, so we can have both
; positive and negative offsets depending on if the tool is shorter
; (positive) or longer (negative) than the dowel used to calibrate
; the toolsetter.

if { state.currentTool == -1 }
    M291 P"No tool selected. Make sure to select a configured tool using T<N> before running G37!" R"MillenniumOS: Tool Change" S3
    M25.1 S{ "No tool selected. Run T<N> M6 to perform a tool change and then press 'Resume Job' to continue." }

if { state.currentTool == state.previousTool }
    echo "Tool #" ^ state.currentTool ^ " is already selected. Skipping tool change."
    M99

; Reset the tool offset before probing
G10 P{state.currentTool} Z0

echo {"Probing tool #" ^ state.currentTool ^ " length at X=" ^ global.mosToolSetterPos[global.mosIX] ^ ", Y=" ^ global.mosToolSetterPos[global.mosIY] }

; Probe towards axis minimum until toolsetter is activated
G6510.1 I{global.mosToolSetterID} J{global.mosToolSetterPos[global.mosIX]} K{global.mosToolSetterPos[global.mosIY]} L{move.axes[global.mosIZ].max} Z{global.mosToolSetterPos[global.mosIZ]}

var toolOffset = { -(abs(global.mosToolSetterPos[global.mosIZ]) - abs(global.mosProbeCoordinate[global.mosIZ])) }

; TODO: We might have positive offsets here given the toolsetter / touch probe is
; calibrated with a dowel that sticks out. We should find a way to make sure the
; positive offset is not higher than the length of the dowel that was used to
; calibrate the toolsetter position, because otherwise we risk ramming the spindle
; nose into things.

if { var.toolOffset > 0 }
    M25.1 S{ "Probed tool has a positive offset! This means it is shorter than your stored datum height, which should be impossible. Fix your tool or reset your datum height by running the Configuration Wizard using G8000." }

echo {"Tool #" ^ state.currentTool ^ " Offset=" ^ var.toolOffset ^ "mm"}

G27 Z1

G10 P{state.currentTool} X0 Y0 Z{var.toolOffset}
