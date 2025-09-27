; nxt-vars.g
; Defines default global variables for the NeXT system.

; --- Features ---
global nxtFeatTouchProbe = false
global nxtFeatToolSetter = false

; --- Core Settings ---
global nxtPTID = limits.tools - 1  ; Probe Tool ID, always the last tool
global nxtErr = null               ; Stores the last error message
global nxtLdd = false              ; Tracks if NeXT has loaded successfully
global nxtUiReady = false          ; Flag to indicate if the NeXT UI is loaded and ready for interaction

; --- Tooling & Probing ---
global nxtDeltaMachine = null      ; The static Z distance between the toolsetter and reference surface
global nxtProbeResults = vector(10, {0.0, 0.0, 0.0}) ; A table to store the last 10 probe results
global nxtToolCache = vector(limits.tools, null) ; A cache for tool measurement results per session
