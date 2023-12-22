; M7000.g: ENABLE VSSC
;
; Enable and configure Variable Spindle Speed Control
;
; USAGE: "M7000 P<period-in-ms> V<variance>"


if { !exists(param.P) }
    abort { "Must specify period (P..) in milliseconds between spindle speed adjustments" }

if { !exists(param.V) }
    abort { "Must specify variance (V..) in rpm of spindle speed adjustments" }

if { param.P < global.mosDaemonUpdateRate }
    abort { "Period cannot be less than daemonUpdateRate (" ^ global.mosDaemonUpdateRate ^ "ms)" }

if { mod(param.P, global.mosDaemonUpdateRate) > 0 }
    abort { "Period must be a multiple of daemonUpdateRate (" ^ global.mosDaemonUpdateRate ^ ")ms" }

set global.mosVsscPeriod             = param.P
set global.mosVsscVariance           = param.V
set global.mosVsscEnabled            = true
set global.mosVsscSpeedWarningIssued = false

if { global.mosVsscDebug }
    echo {"[VSSC] State: Enabled Period: " ^ param.P ^ "ms Variance: " ^ param.V ^ "RPM" }