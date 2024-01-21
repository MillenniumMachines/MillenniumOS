; G8000.g: MOS CONFIGURATION WIZARD
;
; This command walks the user through configuring MillenniumOS.
; It is triggered automatically when MOS is first loaded, if the
; user-vars.g file does not exist. It can also be run manually but
; please note, it will overwrite your existing mos-user-vars.g file.
; It will try to preserve existing settings but this cannot be
; guaranteed, as you can put anything you like in your mos-user-vars.g
; file.

var wizSpindleID = null
var wizToolSetterID = null
var wizTouchProbeID = null
var wizFeatureTouchProbe = false
var wizFeatureToolsetter = false
var wizToolSetterPos = { null, null }
var wizToolSetterDatum = null

var wizUserVarsFile = "mos-user-vars.g"

M291 P"Welcome to MillenniumOS. This wizard will help you configure MillenniumOS." R"MillenniumOS: Configuration Wizard" S2 T10

M291 P"You will need to configure a spindle and any optional components (touch probe, toolsetter etc) in RRF before continuing. Press OK to continue!" R"MillenniumOS: Configuration Wizard" T0 S3
if { result != 0 }
    M291 P"MillenniumOS: Operator aborted configuration wizard!" R"MillenniumOS: Configuration Wizard" S2 T10
    abort { "MillenniumOS: Operator aborted configuration wizard!" }

; Identify the spindle. We can iterate over the spindle list until
; we find the first one that is configured. We ask the user if
; they want to use that spindle.
while { iterations < #spindles }
    if { spindles[iterations].state == "unconfigured" }
        continue

    M291 P{"Spindle " ^ iterations ^ " is configured (" ^ spindles[iterations].min ^ "-" ^ spindles[iterations].max ^ "RPM). Use this spindle?"} R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
    if { input == 0 }
        set var.wizSpindleID = iterations
        break

; If we don't have a selected spindle at this point, error.
if { var.wizSpindleID == null }
    M291 P"MillenniumOS: No more spindles to try! Please configure a spindle in RRF and try again." R"MillenniumOS: Configuration Wizard" S2 T10
    abort { "MillenniumOS: No spindle configured!" }


M291 P"Would you like to enable the touch probe feature and detect your touch probe?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
if { input == 0 }
    set var.wizFeatureTouchProbe = true

if { var.wizFeatureTouchProbe }
    M291 P"Please make sure your touch probe is connected to the machine. When ready, press OK, and then manually activate your touch probe until it is detected." R"MillenniumOS: Configuration Wizard" S2 T0

    echo { "Waiting for touch probe activation... "}

    ; Wait for a 100ms activation of any probe for a maximum of 30s
    M8001 D100 W30

    if { global.mosDetectedProbeID == null }
        M291 P"MillenniumOS: Touch probe not detected! Please make sure your probe is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T10
        abort { "MillenniumOS: Touch probe not detected!" }

    set var.wizTouchProbeID = global.mosDetectedProbeID

    M291 P{"Touch probe detected with ID " ^ var.wizTouchProbeID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T10

M291 P"Would you like to enable the toolsetter feature and detect your toolsetter?" R"MillenniumOS: Configuration Wizard" S4 T0 K{"Yes","No"}
if { input == 0 }
    set var.wizFeatureToolsetter = true

if { var.wizFeatureToolsetter }
    M291 P"Please make sure your toolsetter is connected to the machine. When ready, press OK, and then manually activate your toolsetter until it is detected." R"MillenniumOS: Configuration Wizard" S2 T0

    echo { "Waiting for toolsetter activation... "}

    ; Wait for a 100ms activation of any probe for a maximum of 30s
    M8001 D100 W30

    if { global.mosDetectedProbeID == null }
        M291 P"MillenniumOS: Toolsetter not detected! Please make sure your toolsetter is configured correctly in RRF." R"MillenniumOS: Configuration Wizard" S2 T10
        abort { "MillenniumOS: Toolsetter not detected!" }

    set var.wizToolSetterID = global.mosDetectedProbeID

    M291 P{"Toolsetter detected with ID " ^ var.wizToolSetterID ^ "!"} R"MillenniumOS: Configuration Wizard" S2 T10

if { !move.axes[global.mosIX].homed || !move.axes[global.mosIY].homed || !move.axes[global.mosIZ].homed }
    M291 P{"One or more axes are not homed. Press OK to home the machine and continue the wizard."} R"MillenniumOS: Configuration Wizard" S2 T10
    if { result != 0 }
        M291 P"MillenniumOS: Operator aborted machine homing!" R"MillenniumOS: Configuration Wizard" S2 T10
        abort { "MillenniumOS: Operator aborted machine homing!" }
    G28

if { var.wizFeatureToolsetter }
    M291 P{"We need to calibrate the toolsetter position and run an initial probe to find the datum height."} R"MillenniumOS: Configuration Wizard" S2 T0

    M291 P{"Either install a small metal dowel most of the way into the spindle collet (1-2mm stickout), or leave just the collet installed and tightened."} R"MillenniumOS: Configuration Wizard" S2 T0

    M291 P{"Please jog the center of the collet over the center of the toolsetter and press OK. Do not activate the toolsetter yet!"} R"MillenniumOS: Configuration Wizard" X1 Y1 Z1 S3
    if { result != 0 }
        M291 P"MillenniumOS: Operator aborted toolsetter calibration!" R"MillenniumOS: Configuration Wizard" S2 T10
        abort { "MillenniumOS: Operator aborted toolsetter calibration!" }

    set var.wizToolSetterPos = { move.axes[global.mosIX].machinePosition, move.axes[global.mosIY].machinePosition }

    M291 P{"Toolsetter position is X: " ^ var.wizToolSetterPos[0] ^ " Y: " ^ var.wizToolSetterPos[1] ^ ". If this is correct, press OK to probe the toolsetter height."} R"MillenniumOS: Configuration Wizard" S3
    if { result != 0 }
        M291 P"MillenniumOS: Operator aborted toolsetter calibration!" R"MillenniumOS: Configuration Wizard" S2 T10
        abort { "MillenniumOS: Operator aborted toolsetter calibration!" }


    ; Probe
    G6510.1 I{var.wizToolSetterID} L{move.axes[2].machinePosition} Z{move.axes[2].min}
    if { result != 0 }
        M291 P"MillenniumOS: Toolsetter probe failed!" R"MillenniumOS: Configuration Wizard" S2 T10
        abort { "MillenniumOS: Toolsetter probe failed!" }

    set var.wizToolSetterDatum = { global.mosProbeCoordinate[global.mosIZ] }

; Create the mos-user-vars.g file
echo >>{var.wizUserVarsFile} "; mos-user-vars.g: MillenniumOS User Variables"
echo >>{var.wizUserVarsFile} ";"
echo >>{var.wizUserVarsFile} "; This file is automatically generated by the MOS configuration wizard."
echo >>{var.wizUserVarsFile} "; You may edit this file directly, but it will be overwritten"
echo >>{var.wizUserVarsFile} "; if you complete the configuration wizard again."
echo >>{var.wizUserVarsFile} ""

echo >>{var.wizUserVarsFile} "; Features"
echo >>{var.wizUserVarsFile} {"set global.mosFeatureTouchProbe = " ^ var.wizFeatureTouchProbe}
echo >>{var.wizUserVarsFile} {"set global.mosFeatureToolsetter = " ^ var.wizFeatureToolsetter}
echo >>{var.wizUserVarsFile} ""

echo >>{var.wizUserVarsFile} "; Spindle ID"
echo >>{var.wizUserVarsFile} {"set global.mosSpindleID = " ^ var.wizSpindleID}
echo >>{var.wizUserVarsFile} "; Touch Probe ID"
echo >>{var.wizUserVarsFile} {"set global.mosTouchProbeID = " ^ var.wizTouchProbeID}
echo >>{var.wizUserVarsFile} "; Toolsetter ID"
echo >>{var.wizUserVarsFile} {"set global.mosToolSetterID = " ^ var.wizToolSetterID}
echo >>{var.wizUserVarsFile} ""

echo >>{var.wizUserVarsFile} "; Toolsetter Position"
echo >>{var.wizUserVarsFile} {"set global.mosToolSetterPos = {" ^ var.wizToolSetterPos[0] ^ "," ^ var.wizToolSetterPos[1] ^ "}"}
echo >>{var.wizUserVarsFile} "; Toolsetter Datum"
echo >>{var.wizUserVarsFile} {"set global.mosToolSetterDatum = " ^ var.wizToolSetterDatum}


M291 P{"Configuration wizard complete. Your configuration has been saved to " ^ var.wizUserVarsFile ^ " - Press OK to reboot!"} R"MillenniumOS: Configuration Wizard" S2 T10

if { result == 0 }
    echo { "MillenniumOS: Rebooting..."}
    M999
