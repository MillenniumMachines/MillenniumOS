; stop.g - STOP CURRENT JOB

; Called on cancelling or finishing a job.
; Apparently also triggered when pausing.
; Park the spindle.
G27

; Deselect the current tool.
T-1