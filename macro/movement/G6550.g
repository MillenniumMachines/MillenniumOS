; G6550.g: PROTECTED MOVE - EXECUTE
;
; During probing, we might make moves towards or away from a work piece
; that could collide with fixtures, clamps or the workpiece itself.
; We are, after all, relying on operator input to tell us where to move,
; and this is always a potential source of error.
; To avoid this, all moves during a probing operation should be protected,
; and executed using this command.
;
; This command behaves like a normal G1 move, except for the following changes:
;   - You may pass it a probe ID "I", which should refer to a probe that will be
;     checked during movement to detect unintended collisions.
;   - If you do not pass a probe ID, or its' value is null, the move will be
;     executed without any protection. This is to allow for manual probing and back-off
;     with the same command set.
;   - You cannot pass it a feed rate, as the feed rate is determined by the travel
;     speed set on the probe itself.
;   - Our first move will check if the probe is already triggered, and will move towards
;     the target position until the probe becomes un-triggered. It will then make sure
;     the probe is not triggered and move towards the target position until it is triggered
;     again, or until it reaches the target position.
;   - Co-ordinates are absolute, in mm and machine co-ordinates only!
;
; If this command errors, it means that the probe has collided when generally
; it should not have. This is a critical failure and should stop the current job.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.I) && param.I != null && (sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8) }
    abort { "G6550: Invalid probe ID (I..), probe must be of type 5 or 8, or unset for manual probing." }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6550: Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

var manualProbe = { !exists(param.I) || param.I == null }

; Make sure machine is stationary before checking machine positions
M400

; Generate target position and defaults
var tPX = { (exists(param.X)? param.X : move.axes[0].machinePosition) }
var tPY = { (exists(param.Y)? param.Y : move.axes[1].machinePosition) }
var tPZ = { (exists(param.Z)? param.Z : move.axes[2].machinePosition) }

if { var.tPX == move.axes[0].machinePosition && var.tPY == move.axes[1].machinePosition && var.tPZ == move.axes[2].machinePosition }
    ; Commented due to memory limitations
    ; M7500 S{"G6550: Target position is the same as the current position, no move required."}
    M99

; Check if the positions are within machine limits
M6515 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; If we're using "manual" probing, we can't
; protect any moves as we have no inputs to check.
; So just run the move as normal with our manual
; probing travel speed and then return.
if { var.manualProbe }
    G53 G1 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ } F{ global.mosMPS[0] }
    M99

; Commented due to memory limitations
; M7500 S{"Protected move to X=" ^ var.tPX ^ " Y=" ^ var.tPY ^ " Z=" ^ var.tPZ ^ " from X=" ^ move.axes[0].machinePosition ^ " Y=" ^ move.axes[1].machinePosition ^ " Z=" ^ move.axes[2].machinePosition }

; Note: these must be set as variables as we override the
; probe speed below. We need to reset the probe speed
; after the move.
var roughSpeed   = { sensors.probes[param.I].speeds[0] }
var fineSpeed    = { sensors.probes[param.I].speeds[1] }


; If the sensor is already triggered, we need to back-off slightly first
; before backing off the full distance while waiting for the sensor to
; trigger. When the sensor is _NOT_ triggered, it should read a value of
; 0.
if { sensors.probes[param.I].value[0] != 0 }
    ; We want to move towards the target position by global.mosPMBO
    ; to ensure that the probe is not triggered when we call G38.3.

    ; Calculate target normal
    var tN = { sqrt(pow((var.tPX - move.axes[0].machinePosition), 2) + pow((var.tPY - move.axes[1].machinePosition), 2) + pow((var.tPZ - move.axes[2].machinePosition), 2)) }

    if { var.tN == 0 }
        abort {"G6550: Probe is triggered and we have no direction to back-off in. You will need to manually move the probe out of harms way!" }

    ; Calculate X,Y and Z co-ordinates for initial move.
    var tDX = { ((var.tPX - move.axes[0].machinePosition) / var.tN) * (global.mosPMBO) }
    var tDY = { ((var.tPY - move.axes[1].machinePosition) / var.tN) * (global.mosPMBO) }
    var tDZ = { ((var.tPZ - move.axes[2].machinePosition) / var.tN) * (global.mosPMBO) }

    ; Calculate straight line distance from current position to initial
    ; move position
    var tIN = { sqrt(pow(var.tDX, 2) + pow(var.tDY, 2) + pow(var.tDZ, 2)) }

    ; Commented due to memory limitations
    ; M7500 S{"Probe is triggered at start position. Must back off until probe deactivates."}
    ; Commented due to memory limitations
    ; M7500 S{"Backoff Target position X=" ^ var.tDX ^ " Y=" ^ var.tDY ^ " Z=" ^ var.tDZ ^ " Distance to target: " ^ var.tN ^ " Back-off distance: " ^ var.tIN }

    if { var.tIN >= var.tN }
        abort {"G6550: Probe is triggered and global.mosPMBO=" ^ global.mosPMBO ^ " is greater than the distance to the target position! You will need to manually move the probe out of harms way!" }

    ; Back off by the back-off distance
    ; We do not use a G38.5 here because it will stop movement the
    ; instant the probe is triggered. It is possible, although it
    ; happens rarely, for the probe to deactivate and then re-activate
    ; because it is still slightly in contact with the surface.
    ; It is better to just move the backoff distance and assume that it
    ; is short enough to not damage the probe.
    G53 G1 X{ move.axes[0].machinePosition + var.tDX} Y{ move.axes[1].machinePosition + var.tDY } Z{ move.axes[2].machinePosition + var.tDZ } F{ var.roughSpeed }

    ; Wait for moves to complete
    M400

    ; Commented due to memory limitations
    ; M7500 S{"Probe back-off deactivated at X=" ^ move.axes[0].machinePosition ^ " Y=" ^ move.axes[1].machinePosition ^ " Z=" ^ move.axes[2].machinePosition }

    ; Check if probe is still triggered.
    if { sensors.probes[param.I].value[0] != 0 }
        abort {"G6550: Probe is still triggered after backing off by " ^ global.mosPMBO ^ "mm. You will need to manually move the probe out of harms way!" }

M558 K{ param.I } F{ sensors.probes[param.I].travelSpeed }

; Move to position while checking probe for activation
G53 G38.3 K{ param.I } X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

; Wait for moves to complete
M400

; Reset probe speed
M558 K{ param.I } F{ var.roughSpeed, var.fineSpeed }

; Probing move either complete or stopped due to collision, we need to
; check the location of the machine to determine if the move was completed.
var tolerance = 0.01

if { (move.axes[0].machinePosition) < (var.tPX - var.tolerance/2) || (move.axes[0].machinePosition) > (var.tPX + var.tolerance/2) }
    abort { "G6550: Machine position does not match expected position -  X=" ^ var.tPX ^ " != " ^ move.axes[0].machinePosition }

if { (move.axes[1].machinePosition) < (var.tPY - var.tolerance/2) || (move.axes[1].machinePosition) > (var.tPY + var.tolerance/2) }
    abort { "G6550: Machine position does not match expected position -  Y=" ^ var.tPY ^ " != " ^ move.axes[1].machinePosition }

if { (move.axes[2].machinePosition) < (var.tPZ - var.tolerance/2) || (move.axes[2].machinePosition) > (var.tPZ + var.tolerance/2) }
    abort { "G6550: Machine position does not match expected position -  Z=" ^ var.tPZ ^ " != " ^ move.axes[2].machinePosition }
