; G8000.g: MOS CONFIGURATION WIZARD
;
; This command walks the user through configuring MillenniumOS.
; It is triggered automatically when MOS is first loaded, if the
; user-vars.g file does not exist. It can also be run manually but
; please note, it will overwrite your existing mos-user-vars.g file.

var wizUserVarsFile = "mos-user-vars.g"

; Ask user if they want to reset all settings
var wizReset = false

M291 P"Welcome to MillenniumOS! This wizard will walk you through the configuration process.<br/>You can run this wizard again using <b>G8000</b> or clicking the <b>""Run Configuration Wizard""</b> macro." R"MillenniumOS: Configuration Wizard" S3 T0
if { result == -1 }
    abort { "MillenniumOS: Operator aborted configuration wizard!" }

if { !global.mosExpertMode }
    M291 P"<b>NOTE</b>: No settings will be saved or overwritten until the configuration wizard has been completed." R"MillenniumOS: Configuration Wizard" S2 T0

if { global.mosLoaded }
    M291 P"MillenniumOS is already configured. Click <b>Update</b> to configure any new settings, or <b>Reset</b> to reset all settings and start again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Update","Reset"}
elif { exists(global.mosStartupError) && global.mosStartupError != null }
    M291 P"MillenniumOS could not be loaded due to a startup error.<br/>Click <b>Update</b> to configure any missing settings or <b>Reset</b> to reset all settings and start again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Update","Reset"}

; Reset if requested
set var.wizReset = { (input == 1) }

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
var wizDatumToolRadius = { (exists(global.mosDatumToolRadius) && global.mosDatumToolRadius != null && !var.wizReset) ? global.mosDatumToolRadius : null }

if { !global.mosExpertMode }
    ; Note we use the shortest HTML tags we can get away with because RRF commands are length limited.
    M291 P{"<b>CAUTION</b>: You may need to use small, manual movements using this interface during the configuration process. Please make sure the jog button distances are set appropriately."} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"<b>CAUTION</b>: Follow <b>ALL</b> instructions to the letter, and if you are unsure about any step, please ask for help on our <a target=""_blank"" href=""https://discord.gg/ya4UUj7ax2"">Discord</a>."} R"MillenniumOS: Configuration Wizard" S2 T0
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
            set var.wizSpindleID = { iterations }
            break

; If we don't have a selected spindle at this point, error.
if { var.wizSpindleID == null }
    M291 P"MillenniumOS: No spindle selected! Please configure a spindle in RRF and try again." R"MillenniumOS: Configuration Wizard" S2 T0
    abort { "MillenniumOS: No spindle configured!" }

; Spindle Feedback Feature Enable / Disable
if { var.wizFeatureSpindleFeedback == null }
    M291 P"Would you like to enable the <b>Spindle Feedback</b> feature and detect the feedback input?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    set var.wizFeatureSpindleFeedback = { (input == 0) ? true : false }

    ; Do not display this if the setting was not changed
    if { var.wizFeatureSpindleFeedback }
        M291 P"Spindle Feedback feature not yet implemented, falling back to manual timing of spindle acceleration and deceleration." R"MillenniumOS: Configuration Wizard" S2 T0
        set var.wizFeatureSpindleFeedback = false

; TODO: Do not display this when spindle speed feedback enabled and configured
if { var.wizSpindleAccelSeconds == null || var.wizSpindleDecelSeconds == null }
    M291 P"We need to start the spindle and accelerate to its maximum RPM, to measure how long it takes.<br/><b>CAUTION</b>: Make sure your spindle nut is tightened now!" R"MillenniumOS: Configuration Wizard" S3 T0
    if { result != 0 }

        abort { "MillenniumOS: Operator aborted configuration wizard!" }
    M291 P"When ready, click <b>OK</b> to start the spindle.<br />When it is no longer accelerating, click <b>OK</b> on the next screen." R"MillenniumOS: Configuration Wizard" S2 T0

    ; Store start time
    set var.wizSpindleAccelSeconds = { state.time }

    ; Run spindle up to maximum RPM
    M3 P{var.wizSpindleID} S{spindles[var.wizSpindleID].max}

    ; Prompt user to click OK when the spindle has stopped accelerating
    M291 P"Click <b>OK</b> when the spindle has finished accelerating!" R"MillenniumOS: Configuration Wizard" S2 T0

    ; Calculate the time it took to accelerate
    set var.wizSpindleAccelSeconds = { state.time - var.wizSpindleAccelSeconds }

    ; Prompt to do the same for deceleration
    M291 P"Now we need to measure deceleration. When ready, click <b>OK</b> to stop the spindle.<br />When it has stopped, click <b>OK</b> on the next screen." R"MillenniumOS: Configuration Wizard" S2 T0

    ; Store stop time
    set var.wizSpindleDecelSeconds = { state.time }

    ; Stop spindle
    M5 P{var.wizSpindleID}

    ; Prompt user to click OK when the spindle has stopped decelerating
    M291 P"Click <b>OK</b> when the spindle has stopped!" R"MillenniumOS: Configuration Wizard" S2 T0

    ; Calculate the time it took to accelerate
    set var.wizSpindleDecelSeconds = { state.time - var.wizSpindleDecelSeconds }

    ; Just in case the user forgets to click, or some other issue occurs (clock rollover? lol)
    ; throw an error.
    ; No normal working spindle should take >120s to accelerate or decelerate.
    if { var.wizSpindleAccelSeconds > 120 || var.wizSpindleDecelSeconds > 120 }
        abort { "MillenniumOS: Calculated spindle acceleration or deceleration time is too long!" }

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
        M291 P"MillenniumOS: Touch probe not detected! Please make sure your probe is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T0
        abort { "MillenniumOS: Touch probe not detected!" }

    set var.wizTouchProbeID = global.mosDetectedProbeID
    M291 P{"Touch probe detected with ID " ^ var.wizTouchProbeID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T0

if { var.wizFeatureTouchProbe && var.wizTouchProbeRadius == null }
    ; Ask the operator to measure and enter the touch probe radius.
    M291 P{"Please enter the radius of the touch probe tip. You should measure this with calipers or a micrometer."} R"MillenniumOS: Configuration Wizard" S6 L0.1 H5 F1.0
    set var.wizTouchProbeRadius = { input }

; Probe a rectangular block to calculate the deflection if the touch probe is enabled
if { var.wizFeatureTouchProbe && var.wizTouchProbeDeflection == null }
    M291 P{"We now need to measure the deflection of the touch probe.We will do this by probing a <b>1-2-3 block</b> or other rectangular item of <b>accurate and known dimensions</b> (greater than 10mm per side)."} R"MillenniumOS: Configuration Wizard" S2 T0

    if { (!move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed) }
        M291 P{"One or more axes are not homed.<br/>Press <b>OK</b> to home the machine and continue."} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted machine homing!" }
        G28

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

    M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing towards the item." R"MillenniumOS: Configuration Wizard" J1 T0 S6 F{global.mosProbeOvertravel}
    if { result != 0 }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }

    var probingDepth = { input }

    if { var.probingDepth < 0 }
        abort { "Probing depth must not be negative!" }

    if { !global.mosExpertMode }
        M291 P{"We will now probe the item from 15mm outside each surface, at 2 points along each surface, at a depth of " ^ var.probingDepth ^ "mm.<br/>Press <b>OK</b> to proceed!"} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted configuration wizard!" }

    ; It is possible that our settings have been reset, but the touch probe already
    ; has a deflection value applied to its' tool radius. We must reset the tool radius
    ; back to the wizard value before probing to calculate the deflection.
    var oldRadius = { global.mosToolTable[global.mosProbeToolID][0] }
    set global.mosToolTable[global.mosProbeToolID][0] = { var.wizTouchProbeRadius }

    G6503.1 W{null} H{var.measuredX} I{var.measuredY} T15 O5 J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probingDepth}
    if { global.mosWorkPieceDimensions[0] == null || global.mosWorkPieceDimensions[1] == null }
        abort { "MillenniumOS: Rectangular block probing failed!" }

    var deflectionX = { var.measuredX - global.mosWorkPieceDimensions[0] }
    var deflectionY = { var.measuredY - global.mosWorkPieceDimensions[1] }

    ; We divide the deflection value by 4, as this gives us the deflection value
    ; that we would need to apply to each probe point.
    set var.wizTouchProbeDeflection = { (var.deflectionX + var.deflectionY) / 4 }

    ; Reset the tool radius back to the existing, possibly-deflected value
    ; as we cannot guarantee that the rest of the configuration wizard will
    ; be completed successfully.
    ; On completion, the deflection value will be written to file and will be
    ; applied at the next reboot.
    set global.mosToolTable[global.mosProbeToolID][0] = { var.oldRadius }

    M291 P{"Measured deflection is <b>" ^ var.wizTouchProbeDeflection ^ "mm</b>.<br/>This will be applied to your touch probe on reboot or reload."} R"MillenniumOS: Configuration Wizard" S2 T0

if { var.wizDatumToolRadius == null }
    M291 P{"We now need to choose a <b>datum tool</b>, which can be a metal dowel, a gauge pin or flat tipped endmill."} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"With the Touch Probe feature <b>disabled</b>, the <b>datum tool</b> can be used to probe workpieces and calculate tool offsets."} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"With the Touch Probe feature <b>enabled</b>, the <b>datum tool</b> will be used to take initial measurements that the touch probe requires to calculate offsets correctly."} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"<b>CAUTION</b>: Once the <b>datum tool</b> has been configured, you <b>MUST</b> use the same tool when probing workpieces or the results will not be accurate!"} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"Please enter the <b>radius</b> of your chosen <b>datum tool</b>, in mm. You should measure this with calipers or a micrometer."} R"MillenniumOS: Configuration Wizard" S6 L0.5 H5 F3.0
    set var.wizDatumToolRadius = { input }

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
            M291 P"MillenniumOS: Toolsetter not detected! Please make sure your toolsetter is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T0
            abort { "MillenniumOS: Toolsetter not detected!" }

        set var.wizToolSetterID = global.mosDetectedProbeID

        M291 P{"Toolsetter detected with ID " ^ var.wizToolSetterID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T0

    var needsToolSetterPos = { var.wizFeatureToolSetter && var.wizToolSetterPos == null }

    ; If the toolsetter datum has been probed, then we need to re-calculate the
    ; reference surface offset because it is no longer accurate.
    var needsRefMeasure = { var.wizFeatureTouchProbe && var.wizFeatureToolSetter && (var.wizToolSetterPos == null || var.wizTouchProbeReferencePos == null) }

    var needsHoming = { var.needsToolSetterPos || var.needsRefMeasure }

    if { var.needsHoming && (!move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed) }
        M291 P{"One or more axes are not homed.<br/>Press <b>OK</b> to home the machine and continue."} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted machine homing!" }
        G28

    if { var.needsHoming }
        ; Prompt the user to install a datum tool for the initial probe.
        M291 P{"Please install your <b>datum tool</b> into the spindle with 15-20mm of stickout.<br/><b>CAUTION</b>: Do not remove or adjust it until prompted!"} R"MillenniumOS: Configuration Wizard" S2 T0

    if { var.needsToolSetterPos }
        M291 P{"Now we need to calibrate the toolsetter position.<br/>Please jog the <b>datum tool</b> over the center of the toolsetter - but <b>NOT</b> touching it - and press <b>OK</b>."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
        if { result != 0 }

            abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Save X and Y position, Z is probed in the next step
        set var.wizToolSetterPos = { move.axes[0].machinePosition, move.axes[1].machinePosition, null }

        M291 P{"Toolsetter position is X: " ^ var.wizToolSetterPos[0] ^ " Y: " ^ var.wizToolSetterPos[1] ^ ".<br/>If this is correct, press <b>OK</b> to probe the toolsetter height."} R"MillenniumOS: Configuration Wizard" S3
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Probe
        G6512 I{var.wizToolSetterID} L{move.axes[2].machinePosition} Z{move.axes[2].min}
        if { result != 0 }
            M291 P"MillenniumOS: Toolsetter probe failed!" R"MillenniumOS: Configuration Wizard" S2 T0
            abort { "MillenniumOS: Toolsetter probe failed!" }

        set var.wizToolSetterPos[2] = { global.mosProbeCoordinate[2] }

        G27 Z1

    if { var.needsRefMeasure }
            if { !global.mosExpertMode }
                M291 P"When using both a toolsetter and touch probe, we need to probe a flat reference surface with the touch probe at the start of each job to enable accurate Z positioning and tool offsets." R"MillenniumOS: Configuration Wizard" S2 T0
                M291 P"You can use the machine table itself or your fixture plate as the reference surface, but the height between the reference surface and the toolsetter activation point <b>MUST NOT</b> change." R"MillenniumOS: Configuration Wizard" S2 T0
                M291 P"We now need to measure the distance between the toolsetter activation point and your reference surface using the <b>datum tool</b> to touch the reference surface and record a position." R"MillenniumOS: Configuration Wizard" S3 T0
                if { result != 0 }
                    abort { "MillenniumOS: Operator aborted touch probe calibration!" }

            if { !global.mosExpertMode }
                M291 P"<b>CAUTION</b>: The spindle can apply a lot of force to the table or fixture plate and it is easy to cause damage.<br/>Approach the surface <b>CAREFULLY</b> in steps of 0.1mm or lower when close." R"MillenniumOS: Configuration Wizard" S2 T0

            M291 P{"Please jog the <b>datum tool</b> over the reference surface, until it is just touching.<br/>Press <b>OK</b> when the <b>datum tool</b> is just touching the surface."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
            if { result != 0 }
                abort { "MillenniumOS: Operator aborted touch probe calibration!" }

            ; Store the reference surface position. We will probe the Z height at the probed X and Y position,
            ; using the static distance in Z between the toolsetter datum and the reference surface to calculate
            ; our touch probe offset.
            set var.wizTouchProbeReferencePos = { move.axes[0].machinePosition, move.axes[1].machinePosition, move.axes[2].machinePosition }
            G27 Z1

    if { var.needsHoming }
        M291 P{"You may now remove the <b>datum tool</b> from the spindle."} R"MillenniumOS: Configuration Wizard" S2 T0

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
    echo >>{var.wizUserVarsFile} {"set global.mosTouchProbeDeflection = " ^ var.wizTouchProbeDeflection }

if { var.wizDatumToolRadius != null }
    echo >>{var.wizUserVarsFile} "; Datum Tool Radius"
    echo >>{var.wizUserVarsFile} {"set global.mosDatumToolRadius = " ^ var.wizDatumToolRadius }

if { global.mosLoaded }
    M291 P{"Configuration wizard complete. Your configuration has been saved to " ^ var.wizUserVarsFile ^ ". Press OK to reload!"} R"MillenniumOS: Configuration Wizard" S2 T0
    M9999
else
    M291 P{"Configuration wizard complete. Your configuration has been saved to " ^ var.wizUserVarsFile ^ ". Press OK to reboot!"} R"MillenniumOS: Configuration Wizard" S2 T0
    echo { "MillenniumOS: Rebooting..."}
    M999
