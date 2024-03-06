; M7000.g: ENABLE VSSC
;
; Enable and configure Variable Spindle Speed Control
;
; USAGE: "M7000 P<period-in-ms> V<variance>"


if { !exists(param.P) }
    abort { "Must specify period (P..) in milliseconds between spindle speed adjustments" }

if { !exists(param.V) }
    abort { "Must specify variance (V..) in rpm of spindle speed adjustments" }

if { param.P < global.mosDAEUR }
    abort { "Period cannot be less than daemonUpdateRate (" ^ global.mosDAEUR ^ "ms)" }

if { mod(param.P, global.mosDAEUR) > 0 }
    abort { "Period must be a multiple of daemonUpdateRate (" ^ global.mosDAEUR ^ ")ms" }

set global.mosVSP             = param.P
set global.mosVSV           = param.V
set global.mosVSEnabled            = true
set global.mosVSSW = false

if { global.mosDebug }
    echo {"[VSSC] State: Enabled Period: " ^ param.P ^ "ms Variance: " ^ param.V ^ "RPM" }