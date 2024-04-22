; M2400.g: JUMP TO OPERATION
;
; This macro is used to jump forward while processing a job file.
; We store operation offsets at the start of the file (prior to this
; macro call). When this macro is called, we read the current job
; position in the file, and jump to the new file position. The offset
; of the operations is relative to where the call to M2400 is made.


; Get operation index to jump to
if { !exists(param.I) || param.I < 1 || param.I > #global.mosOI }
    abort { "Must provide an operation index to jump to." }

; Operation index is 1-based but vector is 0-based
var oIN = { param.I -1 }

if { job.file.fileName == null || job.filePosition == null }
    abort { "Job not running, cannot jump forward." }

if { global.mosOI[var.oIN] == null }
    abort { "Operation " ^ var.oIN ^ " does not exist." }

; Calculate the jump offset
var jO = { job.filePosition + global.mosOI[var.oIN] }

if { var.jO < 0 }
    abort { "Invalid operation offset, aborting" }

echo {"Jumping to operation " ^ param.I ^ " at offset " ^ var.jO ^ " in file " ^ job.file.fileName }

; Select the file
M23 { job.file.fileName }
if { result != 0 }
    abort { "Failed to open file " ^ job.file.fileName }

; Set the offset - we need to floor this so it
; is an integer.
M26 S{ floor(var.jO) }
if { result != 0 }
    abort { "Failed to set file offset to " ^ var.jO }

; Jump to the operation
M24
if { result != 0 }
    abort { "Failed to jump to operation " ^ param.I }