; M9.1.g: RECOVERABLE ALL COOLANTS OFF
;
; Disables all possible Coolant Outputs, but allows recovery for pause/resume.

if { !exists(param.R) }
    abort { "Must specify recovery (R..) to know if we are saving or restoring state" }

if { param.R == 0 } ; Saving
    while { iterations < limits.gpOutPorts }
        set global.mosPS[iterations] = state.gpOut[iterations].pwm
        M42 P{iterations} S0
else if { param.R == 1 } ; Restoring
    while { iterations < limits.gpOutPorts }
        M42 P{iterations} S{state.gpOut[iterations].pwm}
        set global.mosPS[iterations] = 0.0
else 
    abort { "Invalid recovery (R..) value. Use 0 for Saving or 1 for Restoring" }
