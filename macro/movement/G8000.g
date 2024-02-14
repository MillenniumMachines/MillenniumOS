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

if { global.mosTutorialMode }
    M291 P"<b>NOTE</b>: No settings will be saved or overwritten until the configuration wizard has been completed." R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P"<b>CAUTION</b>: You can cancel the configuration wizard to finish configuring RRF, but you <b>MUST</b> complete it before trying to use MillenniumOS itself!" R"MillenniumOS: Configuration Wizard" S3 T0

if { global.mosLoaded }
    M291 P"MillenniumOS is already configured. Click <b>Update</b> to configure any new settings, or change persistent modes or features, or <b>Reset</b> to reset all settings and start again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Update","Reset"}
elif { exists(global.mosStartupError) && global.mosStartupError != null }
    M291 P"MillenniumOS could not be loaded due to a startup error.<br/>Click <b>Update</b> to configure any missing settings or <b>Reset</b> to reset all settings and start again." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Update","Reset"}

; Reset if requested
set var.wizReset = { (input == 1) }

; Do not load feature statuses, we should always ask the operator
; if they want to enable or disable a feature.
var wizFeatureTouchProbe = null
var wizFeatureToolSetter = null
var wizFeatureSpindleFeedback = null

; Do not load mode statuses for the same reason.
var wizExpertMode = null
var wizTutorialMode = null

; Load existing vars unless reset was clicked

var wizSpindleID = { (exists(global.mosSpindleID) && global.mosSpindleID != null && !var.wizReset) ? global.mosSpindleID : null }
var wizSpindleAccelSeconds = { (exists(global.mosSpindleAccelSeconds) && global.mosSpindleAccelSeconds != null && !var.wizReset) ? global.mosSpindleAccelSeconds : null }
var wizSpindleDecelSeconds = { (exists(global.mosSpindleDecelSeconds) && global.mosSpindleDecelSeconds != null && !var.wizReset) ? global.mosSpindleDecelSeconds : null }
var wizToolSetterID = { (exists(global.mosToolSetterID) && global.mosToolSetterID != null && !var.wizReset) ? global.mosToolSetterID : null }
var wizTouchProbeID = { (exists(global.mosTouchProbeID) && global.mosTouchProbeID != null && !var.wizReset) ? global.mosTouchProbeID : null }
var wizToolSetterPos = { (exists(global.mosToolSetterPos) && global.mosToolSetterPos != null && !var.wizReset) ? global.mosToolSetterPos : null }
var wizTouchProbeRadius = { (exists(global.mosTouchProbeRadius) && global.mosTouchProbeRadius != null && !var.wizReset) ? global.mosTouchProbeRadius : null }
var wizTouchProbeDeflection = { (exists(global.mosTouchProbeDeflection) && global.mosTouchProbeDeflection != null && !var.wizReset) ? global.mosTouchProbeDeflection : null }
var wizTouchProbeReferencePos = { (exists(global.mosTouchProbeReferencePos) && global.mosTouchProbeReferencePos != null && !var.wizReset) ? global.mosTouchProbeReferencePos : null }
var wizDatumToolRadius = { (exists(global.mosDatumToolRadius) && global.mosDatumToolRadius != null && !var.wizReset) ? global.mosDatumToolRadius : null }

if { global.mosTutorialMode }
    ; Note we use the shortest HTML tags we can get away with because RRF commands are length limited.
    M291 P{"<b>CAUTION</b>: You may need to use small, manual movements using this interface during the configuration process. Please make sure the jog button distances are set appropriately."} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"<b>CAUTION</b>: Follow <b>ALL</b> instructions to the letter, and if you are unsure about any step, please ask for help on our <a target=""_blank"" href=""https://discord.gg/ya4UUj7ax2"">Discord</a>."} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"<b>NOTE</b>: You will need to configure a spindle and any optional components (touch probe, toolsetter etc) in <b>RRF</b> before continuing.<br/>Press <b>OK</b> to continue, or <b>Cancel</b> to abort!"} R"MillenniumOS: Configuration Wizard" T0 S3
    if { result != 0 }
        abort { "MillenniumOS: Operator aborted configuration wizard!" }

M291 P"Would you like to enable <b>Tutorial Mode</b>?<br/><b>Tutorial Mode</b> describes configuration and probing actions in detail before the any action is taken." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F0
set var.wizTutorialMode = { (input == 0) ? true : false }

M291 P"Would you like to enable <b>Expert Mode</b>?<br/><b>Expert Mode</b> disables some confirmation checks before and after operations to reduce operator interaction." R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"} F1
set var.wizExpertMode = { (input == 0) ? true : false }

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
            ; This is necessary because the spindle ID is used to assign tools
            ; later in the wizard process. We need a spindle ID temporarily to setup
            ; tools.
            break

; If we don't have a selected spindle at this point, error.
if { var.wizSpindleID == null }
    M291 P"MillenniumOS: No spindle selected! Please configure a spindle in RRF and try again." R"MillenniumOS: Configuration Wizard" S2 T0
    abort { "MillenniumOS: No spindle configured!" }

; Spindle Feedback Feature Enable / Disable
if { var.wizFeatureSpindleFeedback == null }
    M291 P"Would you like to enable the <b>Spindle Feedback</b> feature?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    set var.wizFeatureSpindleFeedback = { (input == 0) ? true : false }

    ; Do not display this if the setting was not changed
    if { var.wizFeatureSpindleFeedback }
        M291 P"Spindle Feedback feature not yet implemented, falling back to manual timing of spindle acceleration and deceleration." R"MillenniumOS: Configuration Wizard" S2 T0
        set var.wizFeatureSpindleFeedback = false

; TODO: Do not display this when spindle speed feedback enabled and configured
if { var.wizSpindleAccelSeconds == null || var.wizSpindleDecelSeconds == null }
    M291 P"We need to start the spindle and accelerate to its maximum RPM, to measure how long it takes.<br/><b>CAUTION</b>: Remove any tool and make sure your spindle nut is tightened before proceeding!" R"MillenniumOS: Configuration Wizard" S3 T0
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

if { var.wizDatumToolRadius == null }
    if { var.wizTutorialMode }
        M291 P{"We now need to choose a <b>datum tool</b>, which can be a metal dowel, a gauge pin or flat tipped endmill."} R"MillenniumOS: Configuration Wizard" S2 T0
        M291 P{"You will be asked to install this tool in the spindle when necessary for manual probes."} R"MillenniumOS: Configuration Wizard" S2 T0:W
        M291 P{"With the Touch Probe feature <b>disabled</b>, the <b>datum tool</b> can be used to probe workpieces and calculate tool offsets."} R"MillenniumOS: Configuration Wizard" S2 T0
        M291 P{"With the Touch Probe feature <b>enabled</b>, the <b>datum tool</b> will be used to take initial measurements that the touch probe requires to calculate offsets correctly."} R"MillenniumOS: Configuration Wizard" S2 T0
        M291 P{"<b>CAUTION</b>: Once the <b>datum tool</b> has been configured, you <b>MUST</b> use the same tool when probing workpieces manually or the results will not be accurate!"} R"MillenniumOS: Configuration Wizard" S2 T0
    M291 P{"Please enter the <b>radius</b> of your chosen <b>datum tool</b>, in mm. You should measure the diameter with calipers or a micrometer and divide by 2."} R"MillenniumOS: Configuration Wizard" S6 L0.5 H5 F3.0
    set var.wizDatumToolRadius = { input }

; Touch Probe Feature Enable / Disable
if { var.wizFeatureTouchProbe == null }
    M291 P"Would you like to enable the <b>Touch Probe</b> feature?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    set var.wizFeatureTouchProbe = { (input == 0) ? true : false }

; Toolsetter Feature Enable / Disable
if { var.wizFeatureToolSetter == null }
    M291 P"Would you like to enable the <b>Toolsetter</b> feature?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    set var.wizFeatureToolSetter = { (input == 0) ? true : false }

; We configure the toolsetter first. We configure the touch probe reference surface
; directly after this, as the datum tool will still be installed.

; Toolsetter ID Detection
if { var.wizFeatureToolSetter }
    if { var.wizToolSetterID == null }
        M291 P"We now need to detect your toolsetter.<br/><b>CAUTION</b>: Make sure it is connected to the machine.<br/>When ready, press <b>OK</b>, and then manually activate your toolsetter until it is detected." R"MillenniumOS: Configuration Wizard" S2 T0

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

    var needsMeasuring = { var.needsToolSetterPos || var.needsRefMeasure }

    if { var.needsMeasuring && (!move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed) }
        M291 P{"One or more axes are not homed.<br/>Press <b>OK</b> to home the machine and continue."} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted machine homing!" }
        G28

    if { var.needsMeasuring }
        ; Prompt the user to install a datum tool for the initial probe.
        M291 P{"Please install your <b>datum tool</b> into the spindle with 15-20mm of stickout.<br/><b>CAUTION</b>: Do not remove or adjust it until prompted!"} R"MillenniumOS: Configuration Wizard" S2 T0

        ; Remove any existing probe tool so
        ; it can be redefined.
        M4001 P{global.mosProbeToolID}

        ; Add a wizard datum tool using the provided radius
        ; Use a temporary spindle ID for the wizard spindle
        M4000 S{"Wizard Datum Tool"} P{global.mosProbeToolID} R{ var.wizDatumToolRadius } I{var.wizSpindleID}

        ; Switch to the datum tool but don't run any macros
        ; as we already know the datum tool is installed.
        T{global.mosProbeToolID} P0


    if { var.needsToolSetterPos }
        M291 P{"Now we need to calibrate the toolsetter position.<br/>Please jog the <b>datum tool</b> over the center of the toolsetter - but <b>NOT</b> touching it - and press <b>OK</b>."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Save X and Y position, Z is probed in the next step
        set var.wizToolSetterPos = { move.axes[0].machinePosition, move.axes[1].machinePosition, null }

        if { var.wizTutorialMode }
            M291 P{"Toolsetter position is X: " ^ var.wizToolSetterPos[0] ^ " Y: " ^ var.wizToolSetterPos[1] ^ ".<br/>If this is correct, press <b>OK</b> to probe the toolsetter height."} R"MillenniumOS: Configuration Wizard" S3
            if { result != 0 }
                abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

        ; Probe the toolsetter height
        G6512 I{var.wizToolSetterID} L{move.axes[2].machinePosition} Z{move.axes[2].min}
        if { result != 0 }
            M291 P"MillenniumOS: Toolsetter probe failed!" R"MillenniumOS: Configuration Wizard" S2 T0
            abort { "MillenniumOS: Toolsetter probe failed!" }

        set var.wizToolSetterPos[2] = { global.mosProbeCoordinate[2] }

    if { var.needsRefMeasure }
        if { var.wizTutorialMode }
            M291 P"When using both a toolsetter and touch probe, we need to probe a flat reference surface with the touch probe at the start of each job to enable accurate Z positioning and tool offsets." R"MillenniumOS: Configuration Wizard" S2 T0
            M291 P"You can use the machine table itself or your fixture plate as the reference surface, but the height between the reference surface and the toolsetter activation point <b>MUST NOT</b> change." R"MillenniumOS: Configuration Wizard" S2 T0

            M291 P"We now need to measure the distance between the toolsetter activation point and your reference surface using the <b>datum tool</b> to touch the reference surface and record a position." R"MillenniumOS: Configuration Wizard" S3 T0
            if { result != 0 }
                abort { "MillenniumOS: Operator aborted touch probe calibration!" }

            M291 P"<b>CAUTION</b>: The spindle can apply a lot of force to the table or fixture plate and it is easy to cause damage.<br/>Approach the surface <b>CAREFULLY</b> in steps of 0.1mm or lower when close." R"MillenniumOS: Configuration Wizard" S2 T0

        ; Disable the touch probe feature temporarily so we force a manual probe.
        set global.mosFeatureTouchProbe = false

        M291 P{"Please jog the <b>datum tool</b> less than 20mm over the reference surface, but not touching, then press <b>OK</b>."} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted touch probe calibration!" }

        ; Store the reference surface position in X and Y
        set var.wizTouchProbeReferencePos = { move.axes[0].machinePosition, move.axes[1].machinePosition, 0 }

        if { var.wizTutorialMode }
            M291 P{"Using the following probing interface, please move the <b>datum tool</b> until it is just touching the reference surface, then press <b>Finish</b>."} R"MillenniumOS: Configuration Wizard" S2 T0

        G6510.1 R0 W{null} H4 I20 O2 J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition} Z{move.axes[2].machinePosition - 20}

        if { global.mosWorkPieceSurfacePos == null || global.mosWorkPieceSurfaceAxis != "Z" }
            abort { "MillenniumOS: Failed to probe the reference surface!" }

        ; Store the reference surface position in Z
        set var.wizTouchProbeReferencePos[2] = { global.mosWorkPieceSurfacePos }

    if { var.needsMeasuring }
        ; Switch away from the datum tool.
        T-1 P0

        ; Park the spindle to ease the removal of the datum tool.
        G27 Z1

        ; Remove the temporary datum tool.
        M4001 P{global.mosProbeToolID}

        M291 P{"You may now remove the <b>datum tool</b> from the spindle."} R"MillenniumOS: Configuration Wizard" S2 T0


if { var.wizFeatureTouchProbe && var.wizTouchProbeRadius == null }
    ; Ask the operator to measure and enter the touch probe radius.
    M291 P{"Please enter the radius of the touch probe tip. You should measure the diameter with calipers or a micrometer and divide by 2."} R"MillenniumOS: Configuration Wizard" S6 L0.1 H5 F1.0
    set var.wizTouchProbeRadius = { input }

; Touch Probe ID Detection and deflection calibration.
; We must trigger this prompt if deflection is not set, since we actually need to use the
; touch probe. We cannot use tool number guards to check if the touch probe is already
; inserted because that requires a fully configured touch probe!
if { var.wizFeatureTouchProbe && (var.wizTouchProbeID == null || var.wizTouchProbeDeflection == null) }
    M291 P"We now need to detect your touch probe.<br/><b>CAUTION</b>: Please connect and install the probe.<br/>When ready, press <b>OK</b>, and then manually activate your touch probe until it is detected." R"MillenniumOS: Configuration Wizard" S2 T0

    echo { "Waiting for touch probe activation... "}

    ; Wait for a 100ms activation of any probe for a maximum of 30s
    M8001 D100 W30

    if { global.mosDetectedProbeID == null }
        M291 P"MillenniumOS: Touch probe not detected! Please make sure your probe is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T0
        abort { "MillenniumOS: Touch probe not detected!" }

    set var.wizTouchProbeID    = global.mosDetectedProbeID
    set global.mosTouchProbeID = var.wizTouchProbeID

    if { var.wizTutorialMode }
        M291 P{"Touch probe detected with ID " ^ var.wizTouchProbeID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T0

        ; Probe a rectangular block to calculate the deflection if the touch probe is enabled
        M291 P{"We now need to measure the deflection of the touch probe. We will do this by probing a <b>1-2-3 block</b> or other rectangular item of <b>accurate and known dimensions</b> (greater than 10mm per side)."} R"MillenniumOS: Configuration Wizard" S2 T0
    else
        M291 P{"Please move away from the machine, we will now park to enable calibration block installation."} R"MillenniumOS: Configuration Wizard" S2 T0

    if { (!move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed) }
        M291 P{"One or more axes are not homed.<br/>Press <b>OK</b> to home the machine and continue."} R"MillenniumOS: Configuration Wizard" S3 T0
        if { result != 0 }
            abort { "MillenniumOS: Operator aborted machine homing!" }
        G28

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

    M291 P"Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing towards the item." R"MillenniumOS: Configuration Wizard" J1 T0 S6 F{global.mosProbeOvertravel}
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
    set global.mosFeatureTouchProbe = var.wizFeatureTouchProbe

    ; It is possible that our settings have been reset, but the touch probe already
    ; has a deflection value applied to its' tool radius. We must reset the tool radius
    ; back to the wizard value before probing to calculate the deflection.

    ; Remove any existing probe tool so
    ; it can be redefined.
    M4001 P{global.mosProbeToolID}

    ; Add a wizard touch probe using the provided radius
    ; Use a temporary spindle ID for the wizard spindle
    M4000 S{"Wizard Touch Probe"} P{global.mosProbeToolID} R{ var.wizTouchProbeRadius } I{var.wizSpindleID}

    ; Switch to the probe tool.
    T{global.mosProbeToolID} P0

    G6503.1 W{null} H{var.measuredX} I{var.measuredY} T15 O5 J{move.axes[0].machinePosition} K{move.axes[1].machinePosition} L{move.axes[2].machinePosition - var.probingDepth}
    ; Reset after probing so we don't override wizard
    ; settings if it needs to run again.
    set global.mosFeatureTouchProbe = null

    if { global.mosWorkPieceDimensions[0] == null || global.mosWorkPieceDimensions[1] == null }
        T-1 P0
        M4001 P{global.mosProbeToolID}
        abort { "MillenniumOS: Rectangular block probing failed!" }

    if { global.mosTutorialMode }
        M291 P{"Measured block dimensions are <b>X=" ^ global.mosWorkPieceDimensions[0] ^ " Y=" ^ global.mosWorkPieceDimensions[1] ^ "</b>.<br/>Current probe location is over the center of the item."} R"MillenniumOS: Configuration Wizard" S2 T0

    var deflectionX = { (var.measuredX - global.mosWorkPieceDimensions[0])/2 }
    var deflectionY = { (var.measuredY - global.mosWorkPieceDimensions[1])/2 }

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

    if { global.mosTutorialMode }
        M291 P{"Measured deflection is <b>X=" ^ var.wizTouchProbeDeflection[0] ^ " Y=" ^ var.wizTouchProbeDeflection[1] ^ "</b>.<br/>This will be applied to your touch probe on reboot or reload."} R"MillenniumOS: Configuration Wizard" S2 T0

    ; Switch away from the wizard touch probe.
    T-1 P0

    ; Park the spindle to ease the removal of the probe.
    G27 Z1

    M291 P{"Please remove the touch probe now and stow it safely away from the machine. Click <b>OK</b> when stowed safely."} R{"MillenniumOS: Configuration Wizard"} S2

    ; Remove the temporary probe tool.
    M4001 P{global.mosProbeToolID}


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

echo >>{var.wizUserVarsFile} "; Modes"
echo >>{var.wizUserVarsFile} {"set global.mosExpertMode = " ^ var.wizExpertMode}
echo >>{var.wizUserVarsFile} {"set global.mosTutorialMode = " ^ var.wizTutorialMode}
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
