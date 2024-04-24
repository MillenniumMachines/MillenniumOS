; M9.g: ALL COOLANTS OFF
;
; Disables all possible Coolant Outputs.

while { iterations < limits.gpOutPorts }
    M42 P{iterations} S0

