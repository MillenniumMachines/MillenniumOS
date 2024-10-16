; Reset WCS Origins.g
;
; Reset all WCS origins.
while { iterations < limits.workplaces }
    G10 L2 P{iterations} X0 Y0 Z0
end

; Reset any other settings
M502

; Save the config-override.g file
M500