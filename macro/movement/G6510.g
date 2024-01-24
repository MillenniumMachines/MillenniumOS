; G6510.g: SINGLE SURFACE PROBE
;
; Meta macro to gather operator input before executing a
; single surface probe (G6510.1). The macro will explain to
; the operator what is about to happen and ask on which axis
; the user would like to run a probe cycle. The macro will ask
; the operator to jog to the starting location, then enter a
; depth to probe at (in the case of a Z probe, this is how deep
; we will attempt to probe from the starting location).

var axisNames = { "X+", "X-", "Y+", "Y-", "Z-" }
var zProbeI = { #var.axisNames - 1 }

if { !global.mosExpertMode }
    M291 P"This operation finds the location of a surface in a single axis. It will only return an accurate location if the surface it is probing is square with the axis you choose to probe in. You may be asked to enter a probe axis and direction, a depth (in Z) to probe at and to jog the touch probe to a safe starting position. " R"Probe: SINGLE SURFACE" J1 T0 S3
    if { result != 0 }
        abort { "Surface probe aborted!" }

; Prompt for probe axis and direction
M291 P"Select a probing axis and direction:" R"Probe: SURFACE" J1 T0 S4 F{var.zProbeI} K{var.axisNames}
if { result != 0 }
    abort { "Surface probe aborted!" }
else
    var probeAxis = { input }

    M291 P"Please jog the probe near the surface to be probed." R"Probe: SURFACE" X1 Y1 Z1 J1 T0 S3
    if { result != 0 }
        abort { "Surface probe aborted!" }
    else
        ; If this is an X/Y probe, ask for depth
        if { var.probeAxis < var.zProbeI }
            M291 P"Please enter probing depth in mm (positive only!). This is how far the probe will move down from the current location to probe the surface." R"Probe: SURFACE" J1 T0 S6 F{global.mosProbeOvertravel}
            if { result != 0 }
                abort { "Surface probe aborted!" }
            else
                var probeDepth = { input }

                ; Prompt for distance
                M291 P"Please enter probing distance in mm. This is how far the probe will move from the starting position towards the surface. An error will be returned if the probe is not activated after travelling this distance." R"Probe: SURFACE" J1 T0 S6 F{global.mosProbeOvertravel}
                if { result != 0 }
                    abort { "Surface probe aborted!" }
                else
                    var probeTravel = { input }