; Toggle Spindle Feedback.g

if { global.mosFeatSpindleFeedback }
    M291 R"MillenniumOS: Toggle Spindle Feedback" P"Disable Spindle Feedback? We will fall back to manual delays." S3
    if { result == -1 }
        M99

if { global.mosSFCID == null && global.mosSFSID == null }
    M291 R"MillenniumOS: Toggle Spindle Feedback" P"Spindle Feedback has not been configured. Please reconfigure the Spindle settings using the Configuration Wizard first." S2
    M99

set global.mosFeatSpindleFeedback = {!global.mosFeatSpindleFeedback}

echo {"MillenniumOS: Spindle Feedback " ^ (global.mosFeatSpindleFeedback ? "Enabled" : "Disabled")}