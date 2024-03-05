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
        ; We can't load MOS without a mos-user-vars.g file so there's no point
        ; reporting an error when we know what it is.
        if { !fileexists("0:/sys/mos-user-vars.g") }
            echo { "No user configuration file found. Run the configuration wizard with G8000 to silence this warning. MillenniumOS is not loaded." }
            M99
        else
            var startupError = { (exists(global.mosStartupError) && global.mosStartupError != null) ? global.mosStartupError : "Unknown error. Have you added <b>M98 P""mos.g""</b> at the bottom of your <b>config.g</b>?" }
            M291 P{ var.startupError } R"MillenniumOS: Startup Error" S2 T10
            G8000
            M99
    else
        echo { "MillenniumOS: Loaded " ^ global.mosVersion }
