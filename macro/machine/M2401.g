; M2401.g: ADD OPERATION INDEX
;
; This macro is used to set an operation index from the reference
; location that can then be jumped to using a call to M2400.

if { !exists(param.I) || param.I < 1 || param.I > #global.mosOI }
    abort { "Must specify an operation index between 1 and " ^ #global.mosOI }

if { !exists(param.O) || param.O > pow(2,31) }
    abort { "Must specify an offset less than 2GB." }

if { job.file.fileName == null || job.filePosition == null }
    abort { "Cannot set operation offsets outside of a job!" }

if { param.O > job.file.size }
    abort { "Operation offset is past the end of the file!" }

set global.mosOI[param.I-1] = { param.O }