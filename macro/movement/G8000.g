; G8000.g: MOS CONFIGURATION WIZARD
;
; This command walks the user through configuring MillenniumOS.
; It is triggered automatically when MOS is first loaded, if the
; user-vars.g file does not exist. It can also be run manually but
; please note, it will overwrite your existing mos-user-vars.g file.

var wizUserVarsFile = "mos-user-vars.g"

; Note we use the shortest HTML tags we can get away with because RRF commands are length limited.
M291 P"Welcome to MillenniumOS! This wizard will walk you through the configuration process.<br/>You can run this wizard again using <b>G8000</b> or clicking the <b>""Run Configuration Wizard""</b> macro." R"MillenniumOS: Configuration Wizard" S2 T10
M291 P{"<b>CAUTION</b>: You may need to use small, manual movements using this interface during the configuration process. Please make sure the jog button distances are set appropriately."} R"MillenniumOS: Configuration Wizard" S2 T10
M291 P{"<b>CAUTION</b>: Follow <b>ALL</b> instructions to the letter, and if you are unsure about any step, please ask for help on our <a target=""_blank"" href=""https://discord.gg/ya4UUj7ax2"">Discord</a>."} R"MillenniumOS: Configuration Wizard" S2 T10

; Ask user if they want to reset all settings
var wizReset = false

if { global.mosLoaded }
    M291 P"MillenniumOS is already loaded. Click <b>Update</b> to configure any new settings, or <b>Reset</b> to reset all settings and start again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Update","Reset"}
    set var.wizReset = { (input == 1) }
elif { exists(global.mosStartupError) && global.mosStartupError != null }
    M291 P"MillenniumOS could not be loaded due to a startup error.<br/>Click <b>Reset</b> to reset all settings and start the configuration process again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Reset","Cancel"}
    if { (input != 0) }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }
    set var.wizReset = true

; Load existing vars unless reset was clicked
var wizSpindleID = { (exists(global.mosSpindleID) && global.mosSpindleID != null && !var.wizReset) ? global.mosSpindleID : null }
var wizSpindleAccelSeconds = { (exists(global.mosSpindleAccelSeconds) && global.mosSpindleAccelSeconds != null && !var.wizReset) ? global.mosSpindleAccelSeconds : null }
var wizSpindleDecelSeconds = { (exists(global.mosSpindleDecelSeconds) && global.mosSpindleDecelSeconds != null && !var.wizReset) ? global.mosSpindleDecelSeconds : null }
var wizToolSetterID = { (exists(global.mosToolSetterID) && global.mosToolSetterID != null && !var.wizReset) ? global.mosToolSetterID : null }
var wizTouchProbeID = { (exists(global.mosTouchProbeID) && global.mosTouchProbeID != null && !var.wizReset) ? global.mosTouchProbeID : null }
var wizFeatureTouchProbe = { (exists(global.mosFeatureTouchProbe) && global.mosFeatureTouchProbe != null && !var.wizReset) ? global.mosFeatureTouchProbe : null }
var wizFeatureToolSetter = { (exists(global.mosFeatureToolSetter) && global.mosFeatureToolSetter != null && !var.wizReset) ? global.mosFeatureToolSetter : null }
var wizFeatureSpindleFeedback = { (exists(global.mosFeatureSpindleFeedback) && global.mosFeatureSpindleFeedback != null && !var.wizReset) ? global.mosFeatureSpindleFeedback : null }
var wizToolSetterPos = { (exists(global.mosToolSetterPos) && global.mosToolSetterPos != null && !var.wizReset) ? global.mosToolSetterPos : null }
var wizTouchProbeRadius = { (exists(global.mosTouchProbeRadius) && global.mosTouchProbeRadius != null && !var.wizReset) ? global.mosTouchProbeRadius : null }
var wizTouchProbeDeflection = { (exists(global.mosTouchProbeDeflection) && global.mosTouchProbeDeflection != null && !var.wizReset) ? global.mosTouchProbeDeflection : null }
var wizTouchProbeReferencePos = { (exists(global.mosTouchProbeReferencePos) && global.mosTouchProbeReferencePos != null && !var.wizReset) ? global.mosTouchProbeReferencePos : null }

M291 P{"<b>NOTE</b>: You will need to configure a spindle and any optional components (touch probe, toolsetter etc) in <b>RRF</b> before continuing.<br/>Press <b>OK</b> to continue, or <b>Cancel</b> to abort!"} R"MillenniumOS: Configuration Wizard" T0 S3
if { result != 0 }

    abort { "MillenniumOS: Operator aborted configuration wizard!" }

; Spindle ID Detection
if { var.wizSpindleID == null }
    ; Identify the spindle. We can iterate over the spindle list until
    ; we find the first one that is configured. We ask the user if
    ; they want to use that spindle.
    while { iterations < #spindles }
        if { spindles[iterations].state == "unconfigured" }
            continue

        M291 P{"Spindle " ^ iterations ^ " is configured (" ^ spindles[iterations].min ^ "-" ^ spindles[iterations].max ^ "RPM).<br/>Use this spindle?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
        if { input == 0 }
            set var.wizSpindleID = { iterations+1 }
            break

; If we don't have a selected spindle at this point, error.
if { var.wizSpindleID == null }
    M291 P"MillenniumOS: No spindle selected! Please configure a spindle in RRF and try again." R"MillenniumOS: Configuration Wizard" S2 T10
    abort { "MillenniumOS: No spindle configured!" }

; Spindle Feedback Feature Enable / Disable
if { var.wizFeatureSpindleFeedback == null }
    M291 P"Would you like to enable the <b>Spindle Feedback</b> feature and detect the feedback input?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    set var.wizFeatureSpindleFeedback = { (input == 0) ? true : false }

    ; Do not display this if the setting was not changed
    if { var.wizFeatureSpindleFeedback }
        M291 P"Spindle Feedback feature not yet implemented, falling back to manual timing of spindle acceleration and deceleration." R"MillenniumOS: Configuration Wizard" S2 T10

; TODO: Do not display this when spindle speed feedback enabled and configured
if { var.wizSpindleAccelSeconds == null || var.wizSpindleDecelSeconds == null }
    M291 P"We need to start the spindle and accelerate to its maximum RPM, to measure how long it takes.<br/><b>CAUTION</b>: Make sure your spindle nut is tightened now!" R"MillenniumOS: Configuration Wizard" S3 T0
    if { result != 0 }

        abort { "MillenniumOS: Operator aborted configuration wizard!" }
    M291 P"When ready, click <b>OK</b> to start the spindle.<br />When it is no longer accelerating, click <b>OK</b> on the next screen." R"MillenniumOS: Configuration Wizard" S2 T10

    ; Store start uptime
    set var.wizSpindleAccelSeconds = state.upTime

    ; Run spindle up to maximum RPM
    M3 P{var.wizSpindleID} S{spindles[var.wizSpindleID].max}

    ; Prompt user to click OK when the spindle has stopped accelerating
    M291 P"Click <b>OK</b> when the spindle has finished accelerating!" R"MillenniumOS: Configuration Wizard" S2 T10

    ; Calculate the time it took to accelerate
    set var.wizSpindleDecelSeconds = state.upTime - var.wizSpindleAccelSeconds

    ; Prompt to do the same for deceleration
    M291 P"Now we need to measure deceleration. When ready, click <b>OK</b> to stop the spindle.<br />When it has stopped, click <b>OK</b> on the next screen." R"MillenniumOS: Configuration Wizard" S2 T10

    ; Store start uptime
    set var.wizSpindleDecelSeconds = state.upTime

    ; Stop spindle
    M5 P{var.wizSpindleID}

    ; Prompt user to click OK when the spindle has stopped decelerating
    M291 P"Click <b>OK</b> when the spindle has stopped!" R"MillenniumOS: Configuration Wizard" S2 T10

    ; Calculate the time it took to accelerate
    set var.wizSpindleDecelSeconds = state.upTime - var.wizSpindleDecelSeconds

; Touch Probe Feature Enable / Disable
if { var.wizFeatureTouchProbe == null }
    M291 P"Would you like to enable the <b>Touch Probe</b> feature and detect your touch probe?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    set var.wizFeatureTouchProbe = { (input == 0) ? true : false }

; Touch Probe ID Detection
if { var.wizFeatureTouchProbe && var.wizTouchProbeID == null }
    M291 P"<b>CAUTION</b>: Please make sure your touch probe is connected to the machine.<br/>When ready, press <b>OK</b>, and then manually activate your touch probe until it is detected." R"MillenniumOS: Configuration Wizard" S2 T0

    echo { "Waiting for touch probe activation... "}

    ; Wait for a 100ms activation of any probe for a maximum of 30s
    M8001 D100 W30

    if { global.mosDetectedProbeID == null }
        M291 P"MillenniumOS: Touch probe not detected! Please make sure your probe is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T10
        abort { "MillenniumOS: Touch probe not detected!" }

    set var.wizTouchProbeID = global.mosDetectedProbeID
    M291 P{"Touch probe detected with ID " ^ var.wizTouchProbeID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T10

    ; Ask the operator to measure and enter the touch probe radius.
    M291 P{"Please enter the radius of the touch probe tip. You should measure this with calipers or a micrometer."} R"MillenniumOS: Configuration Wizard" S6 H5 F1.0
    set var.wizTouchProbeRadius = { input }

    ; TODO: Probe a workpiece with a known dimension to calculate the deflection.
    ; For the moment, just set to 0
    set var.wizTouchProbeDeflection = 0

; Toolsetter Feature Enable / Disable
if { var.wizFeatureToolSetter == null}
    M291 P"Would you like to enable the <b>Toolsetter</b> feature and detect your toolsetter?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    set var.wizFeatureToolSetter = { (input == 0) ? true : false }

; Toolsetter ID Detection
if { var.wizFeatureToolSetter }
    if { var.wizToolSetterID == null }
        M291 P"<b>CAUTION</b>: Please make sure your toolsetter is connected to the machine.<br/>When ready, press <b>OK</b>, and then manually activate your toolsetter until it is detected." R"MillenniumOS: Configuration Wizard" S2 T0

        echo { "Waiting for toolsetter activation... "}

        ; Wait for a 100ms activation of any probe for a maximum of 30s
        M8001 D100 W30

        if { global.mosDetectedProbeID == null }
            M291 P"MillenniumOS: Toolsetter not detected! Please make sure your toolsetter is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T10
            abort { "MillenniumOS: Toolsetter not detected!" }

        set var.wizToolSetterID = global.mosDetectedProbeID

        M291 P{"Toolsetter detected with ID " ^ var.wizToolSetterID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T10

    var needsToolSetterPos = { var.wizFeatureToolSetter && var.wizToolSetterPos == null }

    ; If the toolsetter datum has been probed, then we need to re-calculate the
    ; reference surface offset because it is no longer accurate.
    var needsRefMeasure = { var.wizFeatureTouchProbe && var.wizFeatureToolSetter && (var.wizToolSetterPos == null || var.wizTouchProbeReferencePos == null) }

    var needsHoming = { var.needsToolSetterPos || var.needsRefMeasure }

    if { var.needsHoming && (!move.axes[global.mosIX].homed || !move.axes[global.mosIY].homed || !move.axes[global.mosIZ].homed) }
        M291 P{"One or more axes are not homed.<br/>Press <b>OK</b> to home the machine and continue."} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted machine homing!" }
        G28

    if { var.needsHoming }
        ; Prompt the user to install a dowel. This isn't strictly necessary if
        ; the user only has a toolsetter, but it becomes important if they also
        ; have a touch probe - because one of the later steps is to probe the
        ; reference surface. It is likely that the face of the collet will be
        ; recessed slightly inside the spindle nut so measuring without a dowel
        ; will not produce an accurate offset.
        M291 P{"Please install a metal dowel into the spindle with 15-20mm sticking out below the spindle nut, and tighten it up.<br/><b>CAUTION</b>: Do not remove or adjust it until prompted!"} R"MillenniumOS: Configuration Wizard" S2 T0

    if { var.needsToolSetterPos }
        M291 P{"Now we need to calibrate the toolsetter position.<br/>Please jog the dowel over the center of the toolsetter - but <b>NOT</b> touching it - and press <b>OK</b>."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
        if { result != 0 }

            abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Save X and Y position, Z is probed in the next step
        set var.wizToolSetterPos = { move.axes[global.mosIX].machinePosition, move.axes[global.mosIY].machinePosition, null }

        M291 P{"Toolsetter position is X: " ^ var.wizToolSetterPos[0] ^ " Y: " ^ var.wizToolSetterPos[1] ^ ".<br/>If this is correct, press <b>OK</b> to probe the toolsetter height."} R"MillenniumOS: Configuration Wizard" S3
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Probe
        G6510.1 I{var.wizToolSetterID} L{move.axes[2].machinePosition} Z{move.axes[2].min}
        if { result != 0 }
            M291 P"MillenniumOS: Toolsetter probe failed!" R"MillenniumOS: Configuration Wizard" S2 T10
            abort { "MillenniumOS: Toolsetter probe failed!" }

        set var.wizToolSetterPos[global.mosIZ] = { global.mosProbeCoordinate[global.mosIZ] }

        G27 Z1

    if { var.needsRefMeasure }
            M291 P"When using both a toolsetter and touch probe, we need to probe a flat reference surface with the touch probe at the start of each job to enable accurate Z positioning and tool offsets." R"MillenniumOS: Configuration Wizard" S2 T10
            M291 P"You can use the machine table itself or your fixture plate as the reference surface, but the height between the reference surface and the toolsetter activation point <b>MUST NOT</b> change." R"MillenniumOS: Configuration Wizard" S2 T10
            M291 P"We now need to measure the distance between the toolsetter activation point and your chosen reference surface.<br/>You will need to jog the dowel until it is just touching the reference surface." R"MillenniumOS: Configuration Wizard" S3 T0
            if { result != 0 }
                abort { "MillenniumOS: Operator aborted touch probe calibration!" }

            M291 P"<b>CAUTION</b>: The spindle can apply a lot of force to the table or fixture plate and it is easy to cause damage.<br/>Approach the surface <b>CAREFULLY</b> in steps of 0.1mm or lower when close." R"MillenniumOS: Configuration Wizard" S2 T10

            M291 P{"Please jog the dowel over the reference surface, then down until it is just touching.You can slowly rotate the spindle by hand to detect contact.<br/>Press <b>OK</b> when the dowel is touching."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
            if { result != 0 }
                abort { "MillenniumOS: Operator aborted touch probe calibration!" }

            ; Store the reference surface position. We will probe the Z height at the probed X and Y position,
            ; using the static distance in Z between the toolsetter datum and the reference surface to calculate
            ; our touch probe offset.
            set var.wizTouchProbeReferencePos = { move.axes[global.mosIX].machinePosition, move.axes[global.mosIY].machinePosition, move.axes[global.mosIZ].machinePosition }
            G27 Z1

    if { var.needsHoming }
        M291 P{"You may now remove the metal dowel from the spindle."} R"MillenniumOS: Configuration Wizard" S2 T0

; Overwrite the mos-user-vars.g file with the first line
echo >{var.wizUserVarsFile} "; mos-user-vars.g: MillenniumOS User Variables"
echo >>{var.wizUserVarsFile} ";"
echo >>{var.wizUserVarsFile} "; This file is automatically generated by the MOS configuration wizard."
echo >>{var.wizUserVarsFile} "; You may edit this file directly, but it will be overwritten"
echo >>{var.wizUserVarsFile} "; if you complete the configuration wizard again."
echo >>{var.wizUserVarsFile} ""

echo >>{var.wizUserVarsFile} "; Features"
echo >>{var.wizUserVarsFile} {"set global.mosFeatureTouchProbe = " ^ var.wizFeatureTouchProbe}
echo >>{var.wizUserVarsFile} {"set global.mosFeatureToolSetter = " ^ var.wizFeatureToolSetter}
echo >>{var.wizUserVarsFile} {"set global.mosFeatureSpindleFeedback = " ^ var.wizFeatureSpindleFeedback}
echo >>{var.wizUserVarsFile} ""

if { var.wizSpindleID != null }
    echo >>{var.wizUserVarsFile} "; Spindle ID"
    echo >>{var.wizUserVarsFile} { "set global.mosSpindleID = " ^ var.wizSpindleID }

if { var.wizTouchProbeID != null }
    echo >>{var.wizUserVarsFile} "; Touch Probe ID"
    echo >>{var.wizUserVarsFile} {"set global.mosTouchProbeID = " ^ var.wizTouchProbeID}

if { var.wizToolSetterID != null }
    echo >>{var.wizUserVarsFile} "; Toolsetter ID"
    echo >>{var.wizUserVarsFile} {"set global.mosToolSetterID = " ^ var.wizToolSetterID}

echo >>{var.wizUserVarsFile} ""

if { var.wizSpindleAccelSeconds != null }
    echo >>{var.wizUserVarsFile} "; Spindle Acceleration Seconds"
    echo >>{var.wizUserVarsFile} {"set global.mosSpindleAccelSeconds = " ^ var.wizSpindleAccelSeconds}
if { var.wizSpindleDecelSeconds != null }
    echo >>{var.wizUserVarsFile} "; Spindle Deceleration Seconds"
    echo >>{var.wizUserVarsFile} {"set global.mosSpindleDecelSeconds = " ^ var.wizSpindleDecelSeconds}

echo >>{var.wizUserVarsFile} ""

if { var.wizToolSetterPos != null }
    echo >>{var.wizUserVarsFile} "; Toolsetter Position"
    echo >>{var.wizUserVarsFile} {"set global.mosToolSetterPos = " ^ var.wizToolSetterPos }

if { var.wizTouchProbeReferencePos != null }
    echo >>{var.wizUserVarsFile} "; Touch Probe Reference Position"
    echo >>{var.wizUserVarsFile} {"set global.mosTouchProbeReferencePos = " ^ var.wizTouchProbeReferencePos }

echo >>{var.wizUserVarsFile} ""

if { var.wizTouchProbeRadius != null }
    echo >>{var.wizUserVarsFile} "; Touch Probe Radius"
    echo >>{var.wizUserVarsFile} {"set global.mosTouchProbeRadius = " ^ var.wizTouchProbeRadius }
if { var.wizTouchProbeDeflection != null }
    echo >>{var.wizUserVarsFile} "; Touch Probe Deflection"
    echo >>{var.wizUserVarsFile} {"set global.mosTouchProbeDeflection = " ^ var.wizTouchProbeDeflection

M291 P{"Configuration wizard complete. Your configuration has been saved to " ^ var.wizUserVarsFile ^ " - Press <b>OK</b> to reboot!"} R"MillenniumOS: Configuration Wizard" S2 T10

if { result == 0 }
    echo { "MillenniumOS: Rebooting..."}
    M999
