; M3000.g: EMIT CONFIRMATION DIALOG
;
; This macro can be used by post-processors to emit a
; confirmation dialog to the operator. This dialog will
; be preconfigured to allow Continue, Pause or Cancel
; options. The Pause option will only be available if the
; machine is currently running a job. The Cancel option
; will abort the current job.

if { !exists(param.S) || !exists(param.R) }
    abort { "Must provide dialog title (R""..."") and message (S""..."")!" }

var options = null

; Provide a pause option if the machine is running a job and not currently paused
if { job.file.fileName != null && (state.status != "resuming" && state.status != "pausing" && state.status != "paused") }
    set var.options = { "Continue", "Pause", "Cancel" }
else
    set var.options = { "Continue", "Cancel" }

M291 P{param.S} R{"MillenniumOS: " ^ param.R} S4 K{var.options} F0

; If input is the last option in the list, then abort
if { (input+1) == #var.options }
    abort { "Operator cancelled job." }

; Otherwise if input is not the first option,
; then the operator clicked pause.
if { input != 0 }
    M25