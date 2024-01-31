; M25.99.g - PAUSE CURRENT JOB IF ACTIVE
;
; This macro is used in other macros to trigger a machine
; pause if the current job is active. This is so that when
; a warning or error occurs during an active job, the
; user can try to recover the job manually before continuing.

; If the machine is not running a job, then we just abort the
; currently running macro with a message, since it is likely
; the user called the macro manually.
if { job.file.fileName != null }
    echo { param.S }
    if { !global.mosExpertMode }
        M291 P{ param.S } R"MillenniumOS: Paused" S2 T10
    ; Pause the job
    M25
else
    abort { param.S }