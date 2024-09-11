; G6512.g: SINGLE SURFACE PROBE - MANUAL OR AUTOMATED
;
; Surface probe in any direction.
;
; G6512
;    I<optional-probe-id>
;    {X,Y,Z}<one-or-more-target-coord>
;    L<start-coord-z>
;    {J,K}<optional-start-coord-xy>
;
; Implements manual or automated probing of a surface from
; a given position towards a target position.
; When probing manually, the user will be walked through successive
; jogs towards the target position until they are happy that the
; tool is touching the surface.
; When probing automatically, the machine will move towards the
; target position until the given probe ID is activated.
; The probe then resets away from the probed surface by a back-off
; distance in the axes it was moving in. It then repeats the probe
; a number of times to generate an average position in all 3 axes.
; It is up to the calling macro to determine which output coordinates
; from this macro should be used (i.e. if probing horizontally, the
; probed Z coordinate is irrelevant).
;
; NOTE: This macro runs in machine co-ordinates, so do not use
; starting or target positions from non-machine co-ordinate systems!
;
; This probing routine can probe in 1, 2 or 3 axes.
;
; All co-ordinates are absolute machine co-ordinates!
; Examples:
;   G6512 I1 L{move.axes[2].max} Z{move.axes[2].min} -
;     Probe at current X/Y machine position, Z=max towards
;     Z=min using probe 1. This might be used for probing
;     tool offset using the toolsetter.
;
;   G6512 I2 L-10 X100 - Probe from current X/Y machine
;     position at Z=-10 towards X=100 using probe 2.
;     This might be used for probing one side of a workpiece.
;     There would be no movement in the Y or Z directions during
;     the probe movement.
;
;   G6512 I2 J50 K50 L-20 X0 Y0 - Probe from X=50, Y=50,
;     Z=-20 towards X=0, Y=0 (2 axis) using probe 2. This
;     would be a diagonal probing move.
;
;   G6512 I1 J50 K50 L-10 X0 Y0 Z-20 - Probe from X=50,
;     Y=50, Z=-10 towards X=0, Y=0, Z=-20 (3 axis) using
;     probe 1. This would involve movement in all 3 axes
;     at once. Can't think of where this would be useful right now
;     but it's possible!
;
; Remove I<N> from any calls to this macro to run the guided manual jogging process.
;
; This macro is designed to be called directly with parameters set. To gather
; parameters from the user, use the G6510 macro which will prompt the operator
; for the required parameters.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.I) && param.I != null && (sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8) }
    abort { "G6512: Invalid probe ID (I..), probe must be of type 5 or 8, or unset for manual probing." }

var manualProbe = { !exists(param.I) || param.I == null }

; Get current machine position
M5000 P0

; Default to current machine position for unset X/Y starting locations
var sX = { (exists(param.J)) ? param.J : global.mosMI[0] }
var sY = { (exists(param.K)) ? param.K : global.mosMI[1] }

; Note: We allow a safe-Z to be provided as a parameter, but default to
; the current Z position. The reason for this is that we cannot always
; assume that the current Z position is safe to move to the starting
; position at. This is particularly important when the PREVIOUS call to
; G6512 was made with a D1 parameter. This param means that the previous
; macro did not return to its' safe height after probing, and that means
; that _our_ safe height would be the current Z position, which is bad.

; So, we allow the safe-Z to be provided as a parameter in those cases
; where the user of this macro (other macros, mostly) know that we can
; make multiple probes at a particular height (e.g. one side-surface of
; a block), but we need to return to the safe height after the last
; probe to perform probing on the other surfaces.

var safeZ = { exists(param.S) ? param.S : global.mosMI[2] }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6512: Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Initial Z height (L...) must be provided by operator as we cannot make safe assumptions
; about where we are probing.
if { !exists(param.L) }
    abort { "G6512: Must provide Z height to begin probing at (L..)!" }

if { state.currentTool >= #tools || state.currentTool < 0 }
    abort { "G6512: No tool selected! Select a tool before probing."}

var sZ = { param.L }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.

var tPX = { exists(param.X)? param.X : var.sX }
var tPY = { exists(param.Y)? param.Y : var.sY }
var tPZ = { exists(param.Z)? param.Z : var.sZ }

; Check if the positions are within machine limits
M6515 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; TODO: It should be possible for these to be the same.
; If we can get G6550 to handle protected and unprotected
; moves then we can simply call the same code for both.


; If starting probe height is above safe height (current Z),
; then move to the starting probe height first.
if { var.sZ > var.safeZ }
    G6550 I{ exists(param.I) ? param.I : null } Z{ var.sZ }

; Move to starting position in X and Y
G6550 I{ exists(param.I) ? param.I : null } X{ var.sX } Y{ var.sY }

; Move to probe height.
; No-op if we already moved above.
G6550 I{ exists(param.I) ? param.I : null } Z{ var.sZ }

; Run automated probing cycle
if { var.manualProbe }
    G6512.2 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }
else
    G6512.1 I{ param.I } X{ var.tPX } Y{ var.tPY } Z{ var.tPZ } R{ exists(param.R) ? param.R : null } E{ exists(param.E) ? param.E : 1 }

; Move to safe height
; If probing move is called with D parameter,
; we stay at the same height.
if { !exists(param.D) }
    G6550 I{ exists(param.I) ? param.I : null } Z{ var.safeZ }

M400

; Calculate tool radius and round the output.
; We round to 3 decimal places (0.001mm) which is
; way more than we actually need, because 1.8 degree
; steppers with 8mm leadscrews aren't that accurate
; anyway.
; We compensate for the tool radius and deflection
; here, so the output should be as close to accurate
; as we can achieve, given well calibrated values of
; tool radius and deflection.

; The tool radius we use here already includes a deflection value
; which is deemed to be the same for each X/Y axis.
; TODO: Is this a safe assumption?

; Calculate the magnitude of the direction vector of probe movement
; Note: We use the target position to calculate the direction vector,
; because it is possible (although _very_ unlikely) for the probe to
; have not moved from the starting location and we do not want to
; divide by zero.
var mag = { sqrt(pow(var.tPX - var.sX, 2) + pow(var.tPY - var.sY, 2)) }

; Only compensate for the tool radius if the probe has moved in the relevant axes.
if { var.mag != 0 }
    ; Adjust the final position along the direction of movement in X and Y
    ; by the tool radius, subtracting the deflection on each axis.
    set global.mosMI[0] = { global.mosMI[0] + (global.mosTT[state.currentTool][0] - global.mosTT[state.currentTool][1][0]) * ((var.tPX - var.sX) / var.mag) }
    set global.mosMI[1] = { global.mosMI[1] + (global.mosTT[state.currentTool][0] - global.mosTT[state.currentTool][1][1]) * ((var.tPY - var.sY) / var.mag) }

; We do not adjust by the tool radius in Z.

; Now we can apply any probe offsets, if they exist.
if { exists(param.I) }
    set global.mosMI[0] = { global.mosMI[0] + sensors.probes[param.I].offsets[0] }
    set global.mosMI[1] = { global.mosMI[1] + sensors.probes[param.I].offsets[1] }

; This does bring up an interesting conundrum though. If you're probing in 2 axes where
; one is Z, then you have no way of knowing whether the probe was triggered by the Z
; movement or the X/Y movement. If the probe is triggered by Z then we would end up
; compensating on the X/Y axes which would not necessarily be correct.

; For these purposes, we have to assume that it is most likely for probes to be run
; in X/Y, _or_ Z, and we have some control over this as we're writing the higher
; level macros.

; Multiply, ceil then divide by this number
; to achieve 3 decimal places of accuracy.
var sDig = 1000

; Round the output variables to 3 decimal places
set global.mosMI[0] = { ceil(global.mosMI[0] * var.sDig) / var.sDig }
set global.mosMI[1] = { ceil(global.mosMI[1] * var.sDig) / var.sDig }
set global.mosMI[2] = { ceil(global.mosMI[2] * var.sDig) / var.sDig }