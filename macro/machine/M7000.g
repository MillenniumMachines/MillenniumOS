; M7000.g: ENABLE VSSC
;
; Enable and configure Variable Spindle Speed Control
;
; USAGE: "M7000 P<period-in-ms> V<variance>"

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.P) }
    abort { "Must specify period (P..) in milliseconds to complete a speed adjustment cycle" }

if { !exists(param.V) }
    abort { "Must specify variance (V..) in rpm of spindle speed adjustment" }

if { param.P < global.mosDAEUR }
    abort { "Period cannot be less than daemonUpdateRate (" ^ global.mosDAEUR ^ "ms)" }

if { mod(param.P, global.mosDAEUR) > 0 }
    abort { "Period must be a multiple of daemonUpdateRate (" ^ global.mosDAEUR ^ ")ms" }

set global.mosVSP           = param.P
set global.mosVSV           = param.V
set global.mosVSEnabled     = true

if { global.mosDebug }
    echo {"[VSSC] State: Enabled Period: " ^ param.P ^ "ms Variance: " ^ param.V ^ "RPM" }