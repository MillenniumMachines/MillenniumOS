; G37.1.g: PROBE Z SURFACE WITH CURRENT TOOL
;
; When the toolsetter is disabled, we have no way of
; calculating relative tool lengths - so we can't know the
; length of the touch probe (if enabled) or probe the length
; of any tools.

; When a tool change occurs, we must re-zero the Z origin of
; the current WCS by using a manual probe with the currently
; installed tool.

; This macro effectively does a single Z surface probe like
; G6510, but without forcing a switch to the probe tool (manual
; or touch probe) first.

; NOTE: YOU SHOULD NEVER USE THIS OUTSIDE OF TOOL CHANGES, AS
; THIS IS COMPLETELY UNTESTED OUTSIDE OF THIS PARTICULAR USAGE
; AND IS NOT DESIGNED AS A GENERALISED PROBING MACRO.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

var wPN = { move.workplaceNumber + 1 }

if { global.mosTM && !global.mosDD[12] }
    M291 P{"The <b>Toolsetter</b> feature is disabled, so you must set the Z origin in the current WCS after each tool change.<br/>We will run a manual probe cycle to do this."} R"MillenniumOS: Reset Z Origin" S2 T0
    M291 P{"You <b>MUST</b> probe the location where WCS " ^ var.wPN ^ " expects the Z origin to be.<br/>Check in your CAM program to confirm where this is!"} R"MillenniumOS: Reset Z Origin" S2 T0
    set global.mosDD[12] = true

; Ask the operator to jog to their chosen starting position
M291 P"Please jog the tool above your origin point in Z.<br/><b>CAUTION</b>: Remember - Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"MillenniumOS: Reset Z Origin" X1 Y1 Z1 T0 S3
if { result != 0 }
    abort { "G37.1: Surface probe aborted!" }


M291 P"Please enter the distance to probe towards the surface in mm." R"MillenniumOS: Reset Z Origin" J1 T0 S6 F{global.mosCL}
if { result != 0 }
    abort { "G37.1: Surface probe aborted!" }

var probeDist = { input }

if { var.probeDist < 0 }
    abort { "G37.1: Probe distance was negative!" }

; Prompt for overtravel distance
M291 P"Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surface to account for any innaccuracy in the dimensions." R"MillenniumOS: Reset Z Origin" J1 T0 S6 F{global.mosOT}
if { result != 0 }
    echo "Probe Abort"
    abort { "G37.1: Surface probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0 }
    abort { "G37.1: Overtravel distance must not be negative!" }

var tPZ = { move.axes[2].machinePosition - var.probeDist - var.overtravel }

; Check if the position is within machine limits
M6515 Z{ var.tPZ }

; Run a manual probe to target Z location
G6512 L{move.axes[2].machinePosition} Z{var.tPZ}

if { global.mosPCZ == null }
    abort { "G37.1: Surface probe failed!" }

; Park in Z
G27 Z1

echo { "MillenniumOS: Setting WCS " ^ var.wPN ^ " Z origin to probed co-ordinate." }
G10 L2 P{var.wPN} Z{global.mosPCZ}