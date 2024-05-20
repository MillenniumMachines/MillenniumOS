; M3000.g: EMIT CONFIRMATION DIALOG
;
; This macro can be used by post-processors to emit a
; confirmation dialog to the operator. This dialog will
; be preconfigured to allow Continue, Pause or Cancel
; options. The Pause option will only be available if the
; machine is currently running a job. The Cancel option
; will abort the current job.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.S) || !exists(param.R) }
    abort { "Must provide dialog title (R""..."") and message (S""..."")!" }

; Do not render dialog during resume, pause or pausing
if { state.status == "resuming" || state.status == "pausing" || state.status == "paused" }
    M99

; Provide a pause option if the machine is running a job and not currently paused
if { job.file.fileName != null }
    M291 P{param.S} R{"MillenniumOS: " ^ param.R} S4 K{"Continue", "Pause", "Cancel"} F0
    if { input > 1 }
        abort { "Operator cancelled job." }
else
    M291 P{param.S} R{"MillenniumOS: " ^ param.R} S4 K{"Continue", "Cancel"} F0
    if { input > 0 }
        abort { "Operator cancelled job." }

; Otherwise if input is not the first option,
; then the operator clicked pause.
if { input != 0 }
    M25