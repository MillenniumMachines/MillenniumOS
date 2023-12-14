; M7000.g
; Enable and configure Variable Spindle Speed Control
;
; USAGE: "M7000 P<period-in-ms> V<variance>"


if { !exists(param.P) }
    abort { "Must specify period (P..) in milliseconds between spindle speed adjustments" }

if { !exists(param.V) }
    abort { "Must specify variance (V..) in rpm of spindle speed adjustments" }

if { param.P < global.daemonUpdateRate }
    abort { "Period cannot be less than daemonUpdateRate (" ^ global.daemonUpdateRate ^ "ms)" }

if { mod(param.P, global.daemonUpdateRate) > 0 }
    abort { "Period must be a multiple of daemonUpdateRate (" ^ global.daemonUpdateRate ^ ")ms" }

set global.vsscPeriod             = param.P
set global.vsscVariance           = param.V
set global.vsscEnabled            = true
set global.vsscSpeedWarningIssued = false

if { global.vsscDebug }
    echo {"[VSSC] State: Enabled Period: " ^ param.P ^ "ms Variance: " ^ param.V ^ "RPM" }