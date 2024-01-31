; M9999.g: RELOAD MOS
;
; Sometimes it is useful to be able to reload MillenniumOS
; on the fly instead of rebooting the mainboard.

echo {"MillenniumOS: Reloading..."}

; Reset startup messages so we can log new ones
if { exists(global.mosStartupMsgsDisplayed) }
    set global.mosStartupMsgsDisplayed = false

var needsDaemonDisabled = { global.mosDaemonEnable }

if { var.needsDaemonDisabled }
    set global.mosDaemonEnable = false
    ; Wait for 2 daemon update cycles to make sure
    ; the daemon script has had a chance to exit.
    G4 P{global.mosDaemonUpdateRate*2}

; Reload MOS base file
M98 P"mos.g"

; Reset daemon status
set global.mosDaemonEnable = { var.needsDaemonDisabled }
