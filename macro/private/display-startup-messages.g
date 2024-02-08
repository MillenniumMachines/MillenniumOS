; display-startup-messages.g: DISPLAY STARTUP MESSAGES
;
; Display any messages from startup. These will appear in DWC the first time the
; operator loads it after a reboot.
; Called from daemon.g so as to not interrupt the startup sequence.

if { !exists(global.mosStartupMsgsDisplayed) }
    global mosStartupMsgsDisplayed = false

if { !global.mosStartupMsgsDisplayed }
    set global.mosStartupMsgsDisplayed = true
    if {(!exists(global.mosLoaded) || !global.mosLoaded)}
        var startupError = { (exists(global.mosStartupError) && global.mosStartupError != null) ? global.mosStartupError : "Unknown error. Have you added <b>M98 P""mos.g""</b> tat the bottom of your <b>config.g</b>?" }
        M291 P{ var.startupError } R"MillenniumOS: Startup Error" S2 T10
        M99
    else
        if { !global.mosExpertMode }
            echo { "MillenniumOS: Loaded " ^ global.mosVersion }
