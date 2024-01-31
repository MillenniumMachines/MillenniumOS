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

if { global.mosTouchProbeToolID != null && global.mosToolSetterActivationPos == null }
    abort { "Touch probe feature is enabled but reference surface has not been probed. Please run <b>G6511</b> before probing tool lengths!" }
    M99

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
    abort { "No tool selected. Run <b>T<N> P0</b> to select a tool before running G37 manually!" }
    M99

if { state.currentTool == state.previousTool }
    echo "Tool #" ^ state.currentTool ^ " is already selected. Skipping tool change."
    M99

; Reset the tool offset before probing
G10 P{state.currentTool} Z0

echo {"Probing tool #" ^ state.currentTool ^ " length at X=" ^ global.mosToolSetterPos[global.mosIX] ^ ", Y=" ^ global.mosToolSetterPos[global.mosIY] }

; Probe towards axis minimum until toolsetter is activated
G6512 I{global.mosToolSetterID} J{global.mosToolSetterPos[global.mosIX]} K{global.mosToolSetterPos[global.mosIY]} L{move.axes[global.mosIZ].max} Z{move.axes[global.mosIZ].min}

; If touch probe is configured, then our position in Z is relative to
; the installed height of the touch probe, which we don't know. What we
; _do_ know is the Z co-ordinate of a reference surface probed by both
; the 'datum tool' and the touch probe, and the Z co-ordinate of the
; expected activation point of the toolsetter when activated by the
; datum tool.
; Using this, we calculate the expected activation point of the toolsetter
; based on the reference surface probed height, and then calculate our
; offset from there instead.

var toolOffset = 0
if { global.mosTouchProbeToolID != null }
    set var.toolOffset = { -(global.mosProbeCoordinate[global.mosIZ] - global.mosToolSetterActivationPos) }
else
    set var.toolOffset = { -(abs(global.mosToolSetterPos[global.mosIZ]) - abs(global.mosProbeCoordinate[global.mosIZ])) }

echo {"Tool #" ^ state.currentTool ^ " Offset=" ^ var.toolOffset ^ "mm"}

; Park spindle centrally
G27

G10 P{state.currentTool} X0 Y0 Z{var.toolOffset}
