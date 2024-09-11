; G8000.g: MOS CONFIGURATION WIZARD
;
; This command walks the user through configuring MillenniumOS.
; It is triggered automatically when MOS is first loaded, if the
; user-vars.g file does not exist. It can also be run manually but
; please note, it will overwrite your existing mos-user-vars.g file.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

var wizUVF = "mos-user-vars.g"
var wizTVF = "mos-resume-vars.g"

var wizResumed = false

; Do not load existing feature statuses, we should always ask the operator
; if they want to enable or disable a feature.
var wizFeatureTouchProbe = null
var wizFeatureToolSetter = null
var wizFeatureSpindleFeedback = null
var wizFeatureCoolantControl = null

; Do not load mode settings either.
var wizExpertMode = null
var wizTutorialMode = null

; Reset options
var wizReset = false
var wizSpindleReset = false
var wizToolSetterReset = false
var wizTouchProbeReset = false
var wizDatumToolReset = false
var wizCoolantReset = false

M291 P"Welcome to MillenniumOS! This wizard will walk you through the configuration process.<br/>You can run this wizard again using <b>G8000</b> or clicking the <b>""Run Configuration Wizard""</b> macro." R"MillenniumOS: Configuration Wizard" S3 T0
if { result == -1 }
    abort { "MillenniumOS: Operator aborted configuration wizard!" }

; If MOS is loaded, allow the user to reset all settings in one go.
; Otherwise, they can choose to reconfigure individual features
; below.
if { global.mosLdd }
    M291 P"MillenniumOS is already configured. Click <b>Continue</b> to re-configure and change persistent modes or features, or <b>Reset</b> to reset all settings and start again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Continue","Reset"}
elif { (exists(global.mosErr) && global.mosErr != null) || state.startupError != null }
    M291 P"MillenniumOS could not be loaded due to a startup error.<br/>Click <b>Update</b> to configure any missing settings or <b>Reset</b> to reset all settings and start again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Update","Reset"}

; Reset if requested
set var.wizReset = { (input == 1) }

; If user doees not want to reset but we have a resume file
if { !var.wizReset && fileexists("0:/sys/" ^ var.wizTVF) }
    ; Allow the user to pick a resume option.
    M291 P"The wizard did not complete the last time it ran!<br/>Click <b>Yes</b> to load stored settings, or <b>No</b> to start the wizard again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes", "No"} F0
    if { input == 0 }
        M98 P{ var.wizTVF }
        ; Load settings that we ask for on every run in the wizard
        ; _except_ when resuming.
        set var.wizExpertMode             = global.mosEM
        set var.wizTutorialMode           = global.mosTM
        set var.wizFeatureToolSetter      = global.mosFeatToolSetter
        set var.wizFeatureTouchProbe      = global.mosFeatTouchProbe
        set var.wizFeatureSpindleFeedback = global.mosFeatSpindleFeedback
        set var.wizFeatureCoolantControl  = global.mosFeatCoolantControl
        set var.wizResumed                = true
    else
        ; Delete the resume file if the user wants to start over.
        M472 P{ "0:/sys/" ^ var.wizTVF }

if { global.mosTM }
    M291 P"<b>NOTE</b>: No settings will be saved or overwritten until the configuration wizard has been completed." R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P"<b>CAUTION</b>: You can cancel the configuration wizard to finish configuring RRF, but you <b>MUST</b> complete it before trying to use MillenniumOS itself!" R"MillenniumOS: Configuration Wizard" S3 T0
    ; Note we use the shortest HTML tags we can get away with because RRF commands are length limited.
    M291 P{"<b>CAUTION</b>: Follow <b>ALL</b> instructions to the letter, and if you are unsure about any step, please ask for help on our <a target=""_blank"" href=""https://discord.gg/ya4UUj7ax2"">Discord</a>."} R"MillenniumOS: Configuration Wizard" S2 T0

if { var.wizTutorialMode == null }
    M291 P"Would you like to enable <b>Tutorial Mode</b>?<br/><b>Tutorial Mode</b> describes configuration and probing actions in detail before any action is taken." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F{ global.mosTM ? 0 : 1 }
    set var.wizTutorialMode = { (input == 0) ? true : false }

if { var.wizExpertMode == null }
    M291 P"Would you like to enable <b>Expert Mode</b>?<br/><b>Expert Mode</b> disables some confirmation checks before and after operations to reduce operator interaction." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F{ global.mosEM ? 0 : 1 }
    set var.wizExpertMode = { (input == 0) ? true : false }

; Last chance to abort out of the wizard and configure RRF
; without wasting any time answering questions.
if { var.wizTutorialMode }
    M291 P{"<b>NOTE</b>: You will need to configure a spindle and any optional components (touch probe, toolsetter etc) in <b>RRF</b> before continuing.<br/>Press <b>OK</b> to continue, or <b>Cancel</b> to abort!"} R"MillenniumOS: Configuration Wizard" T0 S3
    if { result != 0 }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }


; Overwrite the resume mos-user-vars.g file with the first line
; Note that this means that if the user gets _less_ far through the
; wizard this time than the last time then some settings will be
; lost.
echo >{var.wizTVF} "; MillenniumOS User Variables - Temporary Storage for resume"
echo >>{var.wizTVF} ";"
echo >>{var.wizTVF} "; This file is automatically generated by the MOS configuration wizard,"
echo >>{var.wizTVF} "; and will be deleted once the wizard is completed."
echo >>{var.wizTVF} {"set global.mosEM = " ^ var.wizExpertMode}
echo >>{var.wizTVF} {"set global.mosTM = " ^ var.wizTutorialMode}

; If MOS already loaded and not resetting the whole configuration,
; ask if user wants to reconfigure each of the feature sets.
if { !var.wizReset && global.mosLdd && !var.wizResumed }
    M291 P{"Would you like to change the <b>Spindle</b> configuration?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F1
    set var.wizSpindleReset = { (input == 0) }

if { !var.wizReset && global.mosLdd && !var.wizResumed }
    M291 P{"Would you like to change the <b>Coolant Control</b> configuration?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F1
    set var.wizCoolantReset = { (input == 0) }

; If MOS already loaded, ask if user wants to reconfigure datum tool
if { !var.wizReset && global.mosLdd && !var.wizResumed }
    M291 P{"Would you like to change the <b>Datum Tool</b> configuration?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F1
    set var.wizDatumToolReset = { (input == 0) }

if { !var.wizReset && global.mosLdd && !var.wizResumed }
    M291 P{"Would you like to change the <b>Toolsetter</b> configuration?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F1
    set var.wizToolSetterReset = { (input == 0) }

if { !var.wizReset && global.mosLdd && !var.wizResumed }
    M291 P{"Would you like to change the <b>Touch Probe</b> configuration?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F1
    set var.wizTouchProbeReset = { (input == 0) }

; Nullify settings if reset
var wizSpindleID = { (exists(global.mosSID) && global.mosSID != null && !var.wizReset && !var.wizSpindleReset) ? global.mosSID : null }
var wizSpindleAccelSec = { (exists(global.mosSAS) && global.mosSAS != null && !var.wizReset && !var.wizSpindleReset) ? global.mosSAS : null }
var wizSpindleDecelSec = { (exists(global.mosSDS) && global.mosSDS != null && !var.wizReset && !var.wizSpindleReset) ? global.mosSDS : null }
var wizSpindleChangePinID = { (exists(global.mosSFCID) && global.mosSFCID != null && !var.wizReset && !var.wizSpindleReset) ? global.mosSFCID : null }
var wizSpindleStopPinID = { (exists(global.mosSFSID) && global.mosSFSID != null && !var.wizReset && !var.wizSpindleReset) ? global.mosSFSID : null }
var wizCoolantAirPinID = { (exists(global.mosCAID) && global.mosCAID != null && !var.wizReset && !var.wizCoolantReset) ? global.mosCAID : null }
var wizCoolantMistPinID = { (exists(global.mosCMID) && global.mosCMID != null && !var.wizReset && !var.wizCoolantReset) ? global.mosCMID : null }
var wizCoolantFloodPinID = { (exists(global.mosCFID) && global.mosCFID != null && !var.wizReset && !var.wizCoolantReset) ? global.mosCFID : null }
var wizDatumToolRadius = { (exists(global.mosDTR) && global.mosDTR != null && !var.wizReset && !var.wizDatumToolReset) ? global.mosDTR : null }
var wizToolSetterID = { (exists(global.mosTSID) && global.mosTSID != null && !var.wizReset && !var.wizToolSetterReset) ? global.mosTSID : null }
var wizToolSetterPos = { (exists(global.mosTSP) && global.mosTSP != null && !var.wizReset && !var.wizToolSetterReset) ? global.mosTSP : null }
var wizToolSetterRadius = { (exists(global.mosTSR) && global.mosTSR != null && !var.wizReset && !var.wizToolSetterReset) ? global.mosTSR : null }
var wizTouchProbeID = { (exists(global.mosTPID) && global.mosTPID != null && !var.wizReset && !var.wizTouchProbeReset) ? global.mosTPID : null }
var wizTouchProbeRadius = { (exists(global.mosTPR) && global.mosTPR != null && !var.wizReset && !var.wizTouchProbeReset) ? global.mosTPR : null }
var wizTouchProbeDeflection = { (exists(global.mosTPD) && global.mosTPD != null && !var.wizReset && !var.wizTouchProbeReset) ? global.mosTPD : null }
var wizProtectedMoveBackOff = { (exists(global.mosPMBO) && global.mosPMBO != null && !var.wizReset && !var.wizTouchProbeReset && !var.wizToolSetterReset) ? global.mosPMBO : null }

; Touch Probe Ref Surface is reconfigured only if the toolsetter
; is reconfigured. This means you can reconfigure just the touch
; probe, and there is no need to use the datum tool or do manual
; probes if you just want to change the touch probe settings (like
; deflection).
; This is OK, because the reference surface is only used if both
; touch probe _and_ toolsetter are enabled, so we can treat it as
; a toolsetter setting rather than a touch probe one.
; No need to update this if the datum tool changes since it is
; a Z calculation, and radius does not apply.
var wizTouchProbeReferencePos = { (exists(global.mosTPRP) && global.mosTPRP != null && !var.wizReset && !var.wizToolSetterReset) ? global.mosTPRP : null }

; Spindle ID Detection
if { var.wizSpindleID == null }
    ; Identify the spindle. We can iterate over the spindle list until
    ; we find the first one that is configured. We ask the user if
    ; they want to use that spindle.
    while { iterations < #spindles }
        if { spindles[iterations].state == "unconfigured" }
            continue

        M291 P{"Spindle " ^ iterations ^ " is configured (" ^ spindles[iterations].min ^ "-" ^ spindles[iterations].max ^ "RPM).<br/>Use this spindle?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F0
        if { input == 0 }
            set var.wizSpindleID = { iterations }
            ; This is necessary because the spindle ID is used to assign tools
            ; later in the wizard process. We need a spindle ID temporarily to setup
            ; tools.
            break

; If we don't have a selected spindle at this point, error.
if { var.wizSpindleID == null }
    M291 P"MillenniumOS: No spindle selected! Please configure a spindle in RRF and try again." R"MillenniumOS: Configuration Wizard" S2 T0
    abort { "MillenniumOS: No spindle configured!" }

; Write spindle ID to the resume file
echo >>{var.wizTVF} { "set global.mosSID = " ^ var.wizSpindleID }

; Spindle Feedback Feature Enable / Disable
if { var.wizFeatureSpindleFeedback == null }
    M291 P"Would you like to enable the <b>Spindle Feedback</b> feature?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F{ global.mosFeatSpindleFeedback ? 0 : 1}
    set var.wizFeatureSpindleFeedback = { (input == 0) ? true : false }

; Write spindle feedback feature to the resume file
echo >>{var.wizTVF} {"set global.mosFeatSpindleFeedback = " ^ var.wizFeatureSpindleFeedback}

if { var.wizSpindleAccelSec == null || var.wizSpindleDecelSec == null }
    if { var.wizTutorialMode }
        if { var.wizFeatureSpindleFeedback }
            M291 P"The Spindle Feedback feature can be used to detect when a spindle has reached a target speed, has stopped, or both. How you use this will depend on your VFD configuration." R"MillenniumOS: Configuration Wizard" S2 T0
            M291 P"We will start the spindle so we can measure the time it takes to accelerate and decelerate - these values will be used if you disable the Spindle Feedback feature later." R"MillenniumOS: Configuration Wizard" S2 T0
            M291 P"While doing this, we will monitor the state of any configured general purpose inputs and ask you to confirm if these should be used for spindle feedback." R"MillenniumOS: Configuration Wizard" S2 T0

        else
            M291 P"Spindle Feedback is disabled. We need to measure the time it takes for your spindle to accelerate to maximum speed and then decelerate to a stop." R"MillenniumOS: Configuration Wizard" S2 T0

    M291 P"We need to start the spindle and accelerate to its maximum RPM.<br/><b>CAUTION</b>: Remove any tool and make sure your spindle nut is tightened before proceeding!" R"MillenniumOS: Configuration Wizard" S3 T0
    if { result != 0 }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }

    M291 P"When ready, click <b>OK</b> to start the spindle.<br />When it is no longer accelerating, click <b>OK</b> on the next screen to stop the timer." R"MillenniumOS: Configuration Wizard" S3 T0

    var accelPins = { null }
    var decelPins = { null }

    ; If spindle feedback is enabled, use M8003 to check which pins change state during acceleration.
    if { var.wizFeatureSpindleFeedback }
        M8003

    ; Store start time
    set var.wizSpindleAccelSec = { state.time }

    ; Run spindle up to maximum RPM
    M3 P{var.wizSpindleID} S{spindles[var.wizSpindleID].max}

    ; Prompt user to click OK when the spindle has stopped accelerating
    M291 P"Click <b>OK</b> when the spindle has finished accelerating!" R"MillenniumOS: Configuration Wizard" S2 T0

    ; Calculate the time it took to accelerate
    set var.wizSpindleAccelSec = { state.time - var.wizSpindleAccelSec }

    if { var.wizFeatureSpindleFeedback }
        M8003
        set var.accelPins = { global.mosGPD }

    ; Prompt to do the same for deceleration
    M291 P"Now we need to measure deceleration. When ready, click <b>OK</b> to stop the spindle.<br />When it has stopped, click <b>OK</b> on the next screen to stop the timer." R"MillenniumOS: Configuration Wizard" S2 T0

    ; Store stop time
    set var.wizSpindleDecelSec = { state.time }

    ; Stop spindle
    M5 P{var.wizSpindleID}

    if { var.wizFeatureSpindleFeedback }
        M8003

    ; Prompt user to click OK when the spindle has stopped decelerating
    M291 P"Click <b>OK</b> when the spindle has stopped!" R"MillenniumOS: Configuration Wizard" S2 T0

    ; Calculate the time it took to decelerate
    set var.wizSpindleDecelSec = { state.time - var.wizSpindleDecelSec }

    if { var.wizFeatureSpindleFeedback }
        M8003
        set var.decelPins = { global.mosGPD }

    ; Just in case the user forgets to click, or some other issue occurs (clock rollover? lol)
    ; throw an error.
    ; No normal working spindle should take >120s to accelerate or decelerate.
    if { var.wizSpindleAccelSec > 120 || var.wizSpindleDecelSec > 120 }
        abort { "MillenniumOS: Calculated spindle acceleration or deceleration time is too long!" }

    if { var.wizFeatureSpindleFeedback }
        while { iterations < #var.accelPins }
            if { var.accelPins[iterations] }
                M291 P{"GPIO <b>#" ^ iterations ^ "</b> changed state during spindle acceleration. Use this pin for spindle acceleration feedback?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F0
                if { input == 0 }
                    set var.wizSpindleChangePinID = { iterations }
                    break

        while { iterations < #var.decelPins }
            if { var.decelPins[iterations] }
                M291 P{"GPIO <b>#" ^ iterations ^ "</b> changed state during spindle deceleration. Use this pin for spindle deceleration feedback?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F0
                if { input == 0 }
                    set var.wizSpindleStopPinID = { iterations }
                    break

; Write spindle acceleration and deceleration times to the resume file
echo >>{var.wizTVF} {"set global.mosSAS = " ^ var.wizSpindleAccelSec}
echo >>{var.wizTVF} {"set global.mosSDS = " ^ var.wizSpindleDecelSec}

; Write spindle feedback pins to the resume file
echo >>{var.wizTVF} {"set global.mosSFCID = " ^ var.wizSpindleChangePinID}
echo >>{var.wizTVF} {"set global.mosSFSID = " ^ var.wizSpindleStopPinID}

; Coolant Control Feature Enable / Disable
if { var.wizFeatureCoolantControl == null }
    M291 P"Would you like to enable the <b>Coolant Control</b> feature?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F{ global.mosFeatToolSetter ? 0 : 1 }
    set var.wizFeatureCoolantControl = { (input == 0) ? true : false }

; Write feature setting to the resume file
echo >>{var.wizTVF} {"set global.mosFeatCoolantControl = " ^ var.wizFeatureCoolantControl}

if { var.wizFeatureCoolantControl }
    if { #state.gpOut < 1 }
        M291 P"No general purpose outputs are configured - cannot complete <b>Coolant Control</b> configuration.<br />Please configure at least one output using <b>M950</b> and re-run the wizard." R"MillenniumOS: Configuration Wizard" S2 T0
    else
        if { var.wizTutorialMode && (var.wizCoolantAirPinID == null || var.wizCoolantMistPinID == null || var.wizCoolantFloodPinID == null) }
            M291 P"We need to select the output pins that will be used to activate <b>Air</b>, <b>Mist</b> or <b>Flood</b> coolant on your machine." R"MillenniumOS: Configuration Wizard" S2 T0
            M291 P"We will activate each configured output in turn, and you can select which coolant type the active pin is controlling." R"MillenniumOS: Configuration Wizard" S2 T0
            M291 P"If the pin is not controlling a coolant type, select <b>None</b>.<br/><b>CAUTION</b>: If you have output pins hooked up to anything except coolant, <b>PROCEED WITH SEVERE CAUTION</b>." R"MillenniumOS: Configuration Wizard" S3 T0

        while { iterations < #state.gpOut }
            if { state.gpOut[iterations] != null }
                M291 P{"Activate Output Pin <b>#" ^ iterations ^ "</b>?<br/><b>CAUTION</b>: Step away from the machine and remove any loose items before activating!"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F1
                if { input == 0 }
                    M42 P{iterations} S1
                    M291 P{"Select the coolant type controlled by activated Output Pin <b>#" ^ iterations ^ "</b>."} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Air","Mist","Flood","None"} F{max(iterations, 3)}
                    M42 P{iterations} S0

                    ; Assign pin to coolant type
                    if { input == 0 }
                        set var.wizCoolantAirPinID = { iterations }
                    elif { input == 1 }
                        set var.wizCoolantMistPinID = { iterations }
                    elif { input == 2 }
                        set var.wizCoolantFloodPinID = { iterations }

; Write coolant settings to resume file
echo >>{var.wizTVF} {"set global.mosCAID = " ^ var.wizCoolantAirPinID}
echo >>{var.wizTVF} {"set global.mosCMID = " ^ var.wizCoolantMistPinID}
echo >>{var.wizTVF} {"set global.mosCFID = " ^ var.wizCoolantFloodPinID}

if { var.wizDatumToolRadius == null }
    if { var.wizTutorialMode }
        M291 P{"We now need to choose a <b>Datum Tool</b>, which can be a metal dowel, a gauge pin or flat tipped endmill."} R"MillenniumOS: Configuration Wizard" S2 T0
        M291 P{"You will be asked to install this tool in the spindle when necessary for manual probes."} R"MillenniumOS: Configuration Wizard" S2 T0
        M291 P{"With the Touch Probe feature <b>disabled</b>, the <b>Datum Tool</b> can be used to probe workpieces and calculate tool offsets."} R"MillenniumOS: Configuration Wizard" S2 T0
        M291 P{"With the Touch Probe feature <b>enabled</b>, the <b>Datum Tool</b> will be used to take initial measurements that the touch probe requires to calculate offsets correctly."} R"MillenniumOS: Configuration Wizard" S2 T0
        M291 P{"<b>CAUTION</b>: Once the <b>Datum Tool</b> has been configured, you <b>MUST</b> use the same tool when probing workpieces manually or the results will not be accurate!"} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"Please enter the <b>radius</b> of your chosen <b>Datum Tool</b>, in mm. You should measure the diameter with calipers or a micrometer and divide by 2."} R"MillenniumOS: Configuration Wizard" S6 L0.5 H5 F3.0
    set var.wizDatumToolRadius = { input }

; Write datum tool radius to the resume file
echo >>{var.wizTVF} {"set global.mosDTR = " ^ var.wizDatumToolRadius }

; Toolsetter Feature Enable / Disable
if { var.wizFeatureToolSetter == null }
    M291 P"Would you like to enable the <b>Toolsetter</b> feature?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F{ global.mosFeatToolSetter ? 0 : 1 }
    set var.wizFeatureToolSetter = { (input == 0) ? true : false }

; Touch Probe Feature Enable / Disable
if { var.wizFeatureTouchProbe == null }
    M291 P"Would you like to enable the <b>Touch Probe</b> feature?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F{ global.mosFeatTouchProbe ? 0 : 1 }
    set var.wizFeatureTouchProbe = { (input == 0) ? true : false }

; Write feature settings to the resume file
echo >>{var.wizTVF} {"set global.mosFeatTouchProbe = " ^ var.wizFeatureTouchProbe}
echo >>{var.wizTVF} {"set global.mosFeatToolSetter = " ^ var.wizFeatureToolSetter}

; We configure the toolsetter first. We configure the touch probe reference surface
; directly after this, as the datum tool will still be installed.

if { (var.wizFeatureToolSetter || var.wizFeatureTouchProbe) && var.wizProtectedMoveBackOff == null }
    if { var.wizTutorialMode }
        M291 P{"We now need to enter a <b>back-off distance</b> for protected moves.<br/>This is the distance we will initially move when a touch probe or toolsetter is activated, to deactivate it."} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"Please enter the back-off distance for protected moves."} R"MillenniumOS: Configuration Wizard" S6 L0.1 H5 F0.5
    set var.wizProtectedMoveBackOff = { input }
    set global.mosPMBO = var.wizProtectedMoveBackOff

; Write protected move back-off distance to the resume file
if { var.wizProtectedMoveBackOff != null }
    echo >>{var.wizTVF} {"set global.mosPMBO = " ^ var.wizProtectedMoveBackOff }

; Toolsetter ID Detection
if { var.wizFeatureToolSetter }
    if { var.wizToolSetterID == null }
        M291 P"We now need to detect your toolsetter.<br/><b>CAUTION</b>: Make sure it is connected to the machine.<br/>When ready, press <b>OK</b>, and then manually activate your toolsetter until it is detected." R"MillenniumOS: Configuration Wizard" S3 T0

        echo { "Waiting for toolsetter activation... "}

        ; Wait for a 100ms activation of any probe for a maximum of 30s
        M8001 D100 W30

        if { global.mosDPID == null }
            M291 P"MillenniumOS: Toolsetter not detected! Please make sure your toolsetter is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T0
            abort { "MillenniumOS: Toolsetter not detected!" }

        set var.wizToolSetterID = global.mosDPID

        M291 P{"Toolsetter detected with ID " ^ var.wizToolSetterID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T0

    ; Write toolsetter ID to the resume file
    echo >>{var.wizTVF} {"set global.mosTSID = " ^ var.wizToolSetterID}

    var needsToolSetterXYPos = { var.wizToolSetterPos == null || var.wizToolSetterPos[0] == null || var.wizToolSetterPos[1] == null }
    var needsToolSetterZPos = { var.wizToolSetterPos == null || var.wizToolSetterPos[2] == null }

    ; Make sure toolsetter position is always initialised correctly.
    if { var.wizToolSetterPos == null }
        set var.wizToolSetterPos = { null, null, null }

    ; If the toolsetter datum has been probed, then we need to re-calculate the
    ; reference surface offset because it is no longer accurate.
    var needsRefMeasure = { var.wizFeatureTouchProbe && (var.wizToolSetterPos == null || var.wizTouchProbeReferencePos == null) }

    var needsMeasuring = { var.needsToolSetterXYPos || var.needsToolSetterZPos || var.needsRefMeasure }

    if { var.wizToolSetterRadius == null }
        M291 P{"Please enter the <b>radius</b> of the flat surface of your toolsetter surface, in mm."} R"MillenniumOS: Configuration Wizard" S6 L0.1 H25 F3.0
        set var.wizToolSetterRadius = { input }
        ; Write toolsetter radius to the resume file
        echo >>{var.wizTVF} {"set global.mosTSR = " ^ var.wizToolSetterRadius }

    if { var.needsMeasuring }
        if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
            M291 P{"One or more axes are not homed.<br/>Press <b>OK</b> to home the machine and continue."} R"MillenniumOS: Configuration Wizard" S3 T0
            if { result != 0 }
                abort { "MillenniumOS: Operator aborted machine homing!" }
            G28

        ; Prompt the user to install a datum tool for the initial probe.
        M291 P{"Please install your <b>Datum Tool</b> into the spindle so it is able to reach your toolsetter and reference surface.<br/><b>CAUTION</b>: Do not remove or adjust it until prompted!"} R"MillenniumOS: Configuration Wizard" S2 T0

        ; Remove any existing probe tool so
        ; it can be redefined.
        M4001 P{global.mosPTID}

        ; Add a wizard datum tool using the provided radius
        ; Use a temporary spindle ID for the wizard spindle
        M4000 S{"Wizard Datum Tool"} P{global.mosPTID} R{ var.wizDatumToolRadius } I{-1}

        ; Switch to the datum tool but don't run any macros
        ; as we already know the datum tool is installed.
        T{global.mosPTID} P0


    if { var.needsToolSetterXYPos }
        M291 P{"Now we need to calibrate the toolsetter position in X and Y.<br/>Please jog the <b>Datum Tool</b> over the center of the toolsetter and press <b>OK</b>."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Get current machine position
        M5000 P0

        ; Save X and Y position, Z is probed in the next step
        set var.wizToolSetterPos[0] = { global.mosMI[0] }
        set var.wizToolSetterPos[1] = { global.mosMI[1] }

    ; Write toolsetter X and Y position to the resume file
    echo >>{var.wizTVF} {"set global.mosTSP = " ^ var.wizToolSetterPos }


    if { var.needsToolSetterZPos }
        ; If resumed, spindle could won't necessarily be over the toolsetter
        ; position, but it will be homed. Let's just park in Z before moving
        ; to that position just in case.
        if { var.wizResumed }
            M291 P{"Toolsetter position <b>X=" ^ var.wizToolSetterPos[0] ^ " Y=" ^ var.wizToolSetterPos[1] ^ "</b>.<br/>Press <b>OK</b> to move above this position."} R"MillenniumOS: Configuration Wizard" S4 K{"OK","Cancel"}
            if { input != 0 }
                abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

            ; Park Z
            G27 Z1

            ; Move to the toolsetter position
            G53 G0 X{var.wizToolSetterPos[0]} Y{var.wizToolSetterPos[1]}

        M291 P{"Please jog the <b>Datum Tool</b> less than 10mm above the activation point of the toolsetter, then press <b>OK</b> to probe the activation height."} R"MillenniumOS: Configuration Wizard" Z1 S3
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Get current machine position
        M5000 P0

        ; Probe the toolsetter height
        G6512 I{var.wizToolSetterID} L{global.mosMI[2]} Z{global.mosMI[2] - 10}
        if { result != 0 }
            M291 P"MillenniumOS: Toolsetter probe failed! If the toolsetter was not activated, you need to move the tool closer to the switch!" R"MillenniumOS: Configuration Wizard" S2 T0
            abort { "MillenniumOS: Toolsetter probe failed!" }

        set var.wizToolSetterPos[2] = { global.mosMI[2] }

    ; Write toolsetter Z position to the resume file
    echo >>{var.wizTVF} {"set global.mosTSP[2] = " ^ var.wizToolSetterPos[2] }

    if { var.needsRefMeasure }
        if { var.wizTutorialMode }
            M291 P"When using both a toolsetter and touch probe, we need to probe a flat reference surface with the touch probe at the start of each job to enable accurate Z positioning and tool offsets." R"MillenniumOS: Configuration Wizard" S2 T0
            M291 P"You can use the machine table itself or your fixture plate as the reference surface, but the height between the reference surface and the toolsetter activation point <b>MUST NOT</b> change." R"MillenniumOS: Configuration Wizard" S2 T0

            M291 P"We now need to measure the distance between the toolsetter activation point and your reference surface using the <b>Datum Tool</b> to touch the reference surface and record a position." R"MillenniumOS: Configuration Wizard" S3 T0
            if { result != 0 }
                abort { "MillenniumOS: Operator aborted touch probe calibration!" }

            M291 P"<b>CAUTION</b>: The spindle can apply a lot of force to the table or fixture plate and it is easy to cause damage.<br/>Approach the surface <b>CAREFULLY</b> in steps of 0.1mm or lower when close." R"MillenniumOS: Configuration Wizard" S2 T0

        ; Disable the touch probe feature temporarily so we force a manual probe.
        set global.mosFeatTouchProbe = false

        M291 P{"Please jog the <b>Datum Tool</b> just less than 20mm over the reference surface, but not touching, then press <b>OK</b>."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted touch probe calibration!" }

        ; Get current machine position
        M5000 P0

        ; Store the reference surface position in X and Y
        set var.wizTouchProbeReferencePos = { global.mosMI[0], global.mosMI[1], null }

        if { var.wizTutorialMode }
            M291 P{"Using the following probing interface, please move the <b>Datum Tool</b> until it is just touching the reference surface, then press <b>Finish</b>."} R"MillenniumOS: Configuration Wizard" S2 T0

        ; Distance to move towards target is the lower of (min Z - current Z) or 20mm.
        G6510.1 R0 W{null} H4 I{min(abs(move.axes[2].min - global.mosMI[2]), 20)} O0 J{global.mosMI[0]} K{global.mosMI[1]} L{global.mosMI[2]}

        if { global.mosWPSfcPos[move.workplaceNumber] == null || global.mosWPSfcAxis[move.workplaceNumber] != "Z" }
            abort { "MillenniumOS: Failed to probe the reference surface!" }

        ; Store the reference surface position in Z
        set var.wizTouchProbeReferencePos[2] = { global.mosWPSfcPos[move.workplaceNumber] }

    ; Write touch probe reference surface position to the resume file
    echo >>{var.wizTVF} {"set global.mosTPRP = " ^ var.wizTouchProbeReferencePos }

    if { var.needsMeasuring }
        ; Switch away from the datum tool.
        T-1 P0

        ; Park the spindle to ease the removal of the datum tool.
        G27 Z1

        ; Remove the temporary datum tool.
        M4001 P{global.mosPTID}

        M291 P{"You may now remove the <b>Datum Tool</b> from the spindle."} R"MillenniumOS: Configuration Wizard" S2 T0


; Touch Probe ID Detection and deflection calibration.
; We must trigger this prompt if deflection is not set, since we actually need to use the
; touch probe. We cannot use tool number guards to check if the touch probe is already
; inserted because that requires a fully configured touch probe!
if { var.wizFeatureTouchProbe && (var.wizTouchProbeID == null || var.wizTouchProbeDeflection == null || var.wizTouchProbeRadius == null) }
    M291 P"We now need to detect your touch probe.<br/><b>CAUTION</b>: Please connect and install the probe.<br/>When ready, press <b>OK</b>, and then manually activate your touch probe until it is detected." R"MillenniumOS: Configuration Wizard" S2 T0

    echo { "Waiting for touch probe activation... "}

    ; Wait for a 100ms activation of any probe for a maximum of 30s
    M8001 D100 W30

    if { global.mosDPID == null }
        M291 P"MillenniumOS: Touch probe not detected! Please make sure your probe is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T0
        abort { "MillenniumOS: Touch probe not detected!" }

    set var.wizTouchProbeID    = global.mosDPID
    set global.mosTPID         = var.wizTouchProbeID

    ; Write touch probe ID to the resume file
    echo >>{var.wizTVF} {"set global.mosTPID = " ^ var.wizTouchProbeID}

    M291 P{"Touch probe detected with ID " ^ var.wizTouchProbeID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T0

    if { var.wizTouchProbeRadius == null }
        ; Ask the operator to measure and enter the touch probe radius.
        M291 P{"Please enter the radius of the touch probe tip. You should measure the diameter with calipers or a micrometer and divide by 2."} R"MillenniumOS: Configuration Wizard" S6 L0.1 H5 F1.0
        set var.wizTouchProbeRadius = { input }

    ; Write touch probe radius to the resume file
    echo >>{var.wizTVF} {"set global.mosTPR = " ^ var.wizTouchProbeRadius }

    if { var.wizTutorialMode }
        ; Probe a rectangular block to calculate the deflection if the touch probe is enabled
        M291 P{"We now need to measure the deflection of the touch probe. We will do this by probing a <b>1-2-3 block</b> or other rectangular item of <b>accurate and known dimensions</b> (greater than 10mm per side)."} R"MillenniumOS: Configuration Wizard" S2 T0

    if { (!move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed) }
        M291 P{"One or more axes are not homed.<br/>Press <b>OK</b> to home the machine and continue."} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted machine homing!" }
        G28

    M291 P{"We will now move the table to the front of the machine.<br/><b>CAUTION</b>: Please move away from the machine, and remove any obstructions around the table <b>BEFORE</b> clicking <b>OK</b>."} R"MillenniumOS: Configuration Wizard" S3 T0

    ; Park centrally to enable the 1-2-3 block installation
    G27

    M291 P{"Please secure your 1-2-3 block or chosen rectangular item onto the table, largest face on top.<br/><b>CAUTION</b>: Please make sure all 4 side surfaces are free of obstructions!"} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"Please enter the exact <b>surface length</b> of the rectangular item along the X axis in mm.<br/><b>NOTE</b>: Along the X axis means the surface facing towards the operator."} R"MillenniumOS: Configuration Wizard" J1 T0 S6 F50.8
    if { result != 0 }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }

    var measuredX = { input }

    if { var.measuredX < 10 }
        abort { "MillenniumOS: Measured X length is too short, must be at least 10mm!" }

    M291 P{"Please enter the exact <b>surface length</b> of the rectangular item along the Y axis in mm.<br/><b>NOTE</b>: Along the Y axis means the surface facing to the left or right."} R"MillenniumOS: Configuration Wizard" J1 T0 S6 F76.2
    if { result != 0 }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }

    var measuredY = { input }

    if { var.measuredY < 10 }
        abort { "MillenniumOS: Measured Y length is too short, must be at least 10mm!" }

    M291 P{"Jog the touch probe within 5mm of the center of the item and press <b>OK</b>.<br/><b>CAUTION</b>: The probe height when clicking <b>OK</b> is assumed to be safe for horizontal moves!"} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3 T0

    M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing towards the item." R"MillenniumOS: Configuration Wizard" J1 T0 S6 F{global.mosOT}
    if { result != 0 }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }

    var probingDepth = { input }

    if { var.probingDepth < 0 }
        abort { "Probing depth must not be negative!" }

    if { var.wizTutorialMode }
        M291 P{"We will now probe the item from 15mm outside each surface, at 2 points along each surface, at a depth of " ^ var.probingDepth ^ "mm.<br/>Press <b>OK</b> to proceed!"} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted configuration wizard!" }

    ; Enable the feature temporarily so we can use the touch probe later.
    set global.mosFeatTouchProbe = var.wizFeatureTouchProbe

    ; It is possible that our settings have been reset, but the touch probe already
    ; has a deflection value applied to its' tool radius. We must reset the tool radius
    ; back to the wizard value before probing to calculate the deflection.

    ; Remove any existing probe tool so
    ; it can be redefined.
    M4001 P{global.mosPTID}

    ; Add a wizard touch probe using the provided radius
    ; Use a temporary spindle ID for the wizard spindle
    M4000 S{"Wizard Touch Probe"} P{global.mosPTID} R{ var.wizTouchProbeRadius } I{-1}

    ; Switch to the probe tool.
    T{global.mosPTID} P0

    ; Get current machine position
    M5000 P0

    ; Probe the item to calculate deflection.
    G6503.1 W{null} H{var.measuredX} I{var.measuredY} T15 O5 J{global.mosMI[0]} K{global.mosMI[1]} L{global.mosMI[2] - var.probingDepth}

    ; Reset after probing so we don't override wizard
    ; settings if it needs to run again.
    set global.mosFeatTouchProbe = null

    if { global.mosWPDims[move.workplaceNumber][0] == null || global.mosWPDims[move.workplaceNumber][1] == null }
        T-1 P0
        M4001 P{global.mosPTID}
        abort { "MillenniumOS: Rectangular block probing failed!" }

    if { global.mosTM }
        M291 P{"Measured block dimensions are <b>X=" ^ global.mosWPDims[move.workplaceNumber][0] ^ " Y=" ^ global.mosWPDims[move.workplaceNumber][1] ^ "</b>.<br/>Current probe location is over the center of the item."} R"MillenniumOS: Configuration Wizard" S2 T0

    var deflectionX = { (var.measuredX - global.mosWPDims[move.workplaceNumber][0])/2 }
    var deflectionY = { (var.measuredY - global.mosWPDims[move.workplaceNumber][1])/2 }

    ; Deflection values are stored separately per axis, as 3d touch probes almost
    ; always have different deflection values. These are applied during the
    ; compensation stage of the probe routine (G6512) and are multiplied by
    ; the direction of movement of the probe to account for the fact that
    ; probe moves might happen in both X and Y at once.
    set var.wizTouchProbeDeflection = { var.deflectionX, var.deflectionY }

    ; Reset the tool radius back to the existing, possibly-deflected value
    ; as we cannot guarantee that the rest of the configuration wizard will
    ; be completed successfully.
    ; On completion, the deflection value will be written to file and will be
    ; applied at the next reboot.

    M291 P{"Measured deflection is <b>X=" ^ var.wizTouchProbeDeflection[0] ^ " Y=" ^ var.wizTouchProbeDeflection[1] ^ "</b>."} R"MillenniumOS: Configuration Wizard" S2 T0

    ; Switch away from the wizard touch probe.
    T-1 P0

    ; Park the spindle to ease the removal of the probe.
    G27 Z1

    M291 P{"Please remove the touch probe now and stow it safely away from the machine. Click <b>OK</b> when stowed safely."} R{"MillenniumOS: Configuration Wizard"} S2

    ; Remove the temporary probe tool.
    M4001 P{global.mosPTID}

; Write touch probe deflection to the resume file
if { var.wizTouchProbeDeflection != null }
    echo >>{var.wizTVF} {"set global.mosTPD = " ^ var.wizTouchProbeDeflection }


echo >{var.wizUVF} "; mos-user-vars.g: MillenniumOS User Variables"
echo >>{var.wizUVF} ";"
echo >>{var.wizUVF} "; This file is automatically generated by the MOS configuration wizard."
echo >>{var.wizUVF} "; You may edit this file directly, but it will be overwritten"
echo >>{var.wizUVF} "; if you complete the configuration wizard again."
echo >>{var.wizUVF} ""

echo >>{var.wizUVF} "; Features"
echo >>{var.wizUVF} {"set global.mosFeatTouchProbe = " ^ var.wizFeatureTouchProbe}
echo >>{var.wizUVF} {"set global.mosFeatToolSetter = " ^ var.wizFeatureToolSetter}
echo >>{var.wizUVF} {"set global.mosFeatSpindleFeedback = " ^ var.wizFeatureSpindleFeedback}
echo >>{var.wizUVF} {"set global.mosFeatCoolantControl = " ^ var.wizFeatureCoolantControl}
echo >>{var.wizUVF} ""

echo >>{var.wizUVF} "; Modes"
echo >>{var.wizUVF} {"set global.mosEM = " ^ var.wizExpertMode}
echo >>{var.wizUVF} {"set global.mosTM = " ^ var.wizTutorialMode}
echo >>{var.wizUVF} ""

echo >>{var.wizUVF} "; Spindle ID"
echo >>{var.wizUVF} { "set global.mosSID = " ^ var.wizSpindleID }
echo >>{var.wizUVF} "; Spindle Acceleration Sec"
echo >>{var.wizUVF} {"set global.mosSAS = " ^ var.wizSpindleAccelSec}
echo >>{var.wizUVF} "; Spindle Deceleration Sec"
echo >>{var.wizUVF} {"set global.mosSDS = " ^ var.wizSpindleDecelSec}

echo >>{var.wizUVF} "; Spindle Feedback Pins"
echo >>{var.wizUVF} {"set global.mosSFCID = " ^ var.wizSpindleChangePinID}
echo >>{var.wizUVF} {"set global.mosSFSID = " ^ var.wizSpindleStopPinID}
echo >>{var.wizUVF} ""

echo >>{var.wizUVF} "; Coolant Pins"
echo >>{var.wizUVF} {"set global.mosCAID = " ^ var.wizCoolantAirPinID}
echo >>{var.wizUVF} {"set global.mosCMID = " ^ var.wizCoolantMistPinID}
echo >>{var.wizUVF} {"set global.mosCFID = " ^ var.wizCoolantFloodPinID}
echo >>{var.wizUVF} ""

echo >>{var.wizUVF} "; Datum Tool Radius"
echo >>{var.wizUVF} {"set global.mosDTR = " ^ var.wizDatumToolRadius }
echo >>{var.wizUVF} ""

if { var.wizProtectedMoveBackOff != null }
    echo >>{var.wizUVF} "; Protected Move Back-Off"
    echo >>{var.wizUVF} {"set global.mosPMBO = " ^ var.wizProtectedMoveBackOff }
    echo >>{var.wizUVF} ""

if { var.wizTouchProbeID != null }
    echo >>{var.wizUVF} "; Touch Probe ID"
    echo >>{var.wizUVF} { "set global.mosTPID = " ^ var.wizTouchProbeID }
if { var.wizTouchProbeRadius != null }
    echo >>{var.wizUVF} "; Touch Probe Radius"
    echo >>{var.wizUVF} { "set global.mosTPR = " ^ var.wizTouchProbeRadius }
if { var.wizTouchProbeReferencePos != null }
    echo >>{var.wizUVF} "; Touch Probe Reference Position"
    echo >>{var.wizUVF} { "set global.mosTPRP = " ^ var.wizTouchProbeReferencePos }
if { var.wizTouchProbeDeflection != null }
    echo >>{var.wizUVF} "; Touch Probe Deflection"
    echo >>{var.wizUVF} { "set global.mosTPD = " ^ var.wizTouchProbeDeflection }

echo >>{var.wizUVF} ""

if { var.wizToolSetterID != null }
    echo >>{var.wizUVF} "; Toolsetter ID"
    echo >>{var.wizUVF} { "set global.mosTSID = " ^ var.wizToolSetterID }
if { var.wizToolSetterPos != null }
    echo >>{var.wizUVF} "; Toolsetter Position"
    echo >>{var.wizUVF} { "set global.mosTSP = " ^ var.wizToolSetterPos }
if { var.wizToolSetterRadius != null }
    echo >>{var.wizUVF} "; Toolsetter Radius"
    echo >>{var.wizUVF} { "set global.mosTSR = " ^ var.wizToolSetterRadius }

echo >>{var.wizUVF} ""

; Final configuration file has been written, delete the resume file.
M472 P{ "0:/sys/" ^ var.wizTVF }

if { global.mosLdd }
    M291 P{"Configuration wizard complete. Your configuration has been saved to " ^ var.wizUVF ^ ". Press OK to reload!"} R"MillenniumOS: Configuration Wizard" S2 T0
    M9999
else
    M291 P{"Configuration wizard complete. Your configuration has been saved to " ^ var.wizUVF ^ ". Press OK to reboot!"} R"MillenniumOS: Configuration Wizard" S2 T0
    echo { "MillenniumOS: Rebooting..." }
    M999
