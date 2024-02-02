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
    M7500 S{"G6550: Target position is the same as the current position, no move required."}
    M99

; Check if the positions are within machine limits
G6515 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; If we're using "manual" probing, we can't
; protect any moves as we have no inputs to check.
; So just run the move as normal with our manual
; probing travel speed and then return.
if { var.manualProbe }
    M7500 S{"Unprotected move to X=" ^ var.tPX ^ " Y=" ^ var.tPY ^ " Z=" ^ var.tPZ ^ " as touch probe is not available."}
    G53 G1 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ } F{ global.mosManualProbeSpeedTravel }
    M400

else

    ; It is possible that we call this macro while the touch probe
    ; is already triggered, so we need to move away from the surface
    ; before we can watch for the probe being triggered.
    ; We should not move very far when waiting for the probe to
    ; "un-trigger", so we need to back off by the probe radius
    ; towards the target position. We have to assume that the
    ; probe tip will not be touching after backing off by this
    ; amount.

    ; Calculate initial position towards the target to move to
    ; using G38.5. This position should be <probe radius> along
    ; the straight line between the current position ansd the
    ; target position.

    var toolRadius = { global.mosToolTable[state.currentTool][0] }

    ; Calculate normal towards target
    var tN = { sqrt(pow((var.tPX - move.axes[0].machinePosition), 2) + pow((var.tPY - move.axes[1].machinePosition), 2) + pow((var.tPZ - move.axes[2].machinePosition), 2)) }

    var moveMag = { var.tN * var.toolRadius }

    M7500 S{"Probe radius: " ^ var.toolRadius ^ "mm, Target normal: " ^ var.tN }
    M7500 S{"Protected move to X=" ^ var.tPX ^ " Y=" ^ var.tPY ^ " Z=" ^ var.tPZ ^ ". Move magnitude: " ^ var.moveMag }

    ; Calculate distance to move towards target for each axis, first move.
    var tDX = { (var.tPX - move.axes[0].machinePosition) / var.moveMag }
    var tDY = { (var.tPY - move.axes[1].machinePosition) / var.moveMag }
    var tDZ = { (var.tPZ - move.axes[2].machinePosition) / var.moveMag }

    M7500 S{"Initial move positions X=" ^ var.tDX ^ " Y=" ^ var.tDY ^ " Z=" ^ var.tDZ }

    ; Note: these must be set as variables as we override the
    ; probe speed just below. We need to reset the probe speed
    ; after the move.
    var roughSpeed   = { sensors.probes[param.I].speeds[0] }
    var fineSpeed    = { sensors.probes[param.I].speeds[1] }

    ; Configure probe speed
    M558 K{ param.I } F{ sensors.probes[param.I].travelSpeed }

    ; Only perform initial move if the distance to the target is greater
    ; than the calculated initial move distance.
    if { var.moveMag < 1 }
        ; Back off using G38.5 first to ensure we're not already
        ; triggered, which will stop G38.3 from backing away from
        ; the surface.
        ; Store sensor value. We need to make sure when we move away that the
        ; probe is not still triggered.

        var sensorValue = { sensors.probes[param.I].value[0] }

        M7500 S{"Initial move co-ordinates X=" ^ (move.axes[0].machinePosition + var.tDX) ^ " Y=" ^ (move.axes[1].machinePosition + var.tDY) ^ " Z=" ^ (move.axes[2].machinePosition + var.tDZ) }
        G53 G38.5 K{ param.I } X{ move.axes[0].machinePosition + var.tDX} Y{ move.axes[1].machinePosition + var.tDY } Z{ move.axes[2].machinePosition + var.tDZ }

        ; Wait for moves to complete
        M400

        if { sensors.probes[param.I].value[0] == var.sensorValue }
            abort { "Probe is still triggered after initial move, aborting due to safety concerns!" }
    else
        M7500 S{ "Cannot move tool radius " ^ var.toolRadius ^ "mm away from current position as the target is closer! If the probe is already triggered, the following protected move will fail." }

    ; Move to position while checking probe for activation
    G53 G38.3 K{ param.I } X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

    ; Reset probe speed
    M558 K{ param.I } F{ var.roughSpeed, var.fineSpeed }

    ; Wait for moves to complete
    M400

    ; There is a bug in RRF 3.5rc1 that does not update machine position
    ; if it has not been updated in the last 200ms. This is a problem, as
    ; it is possible for the G38.3 command above to return with a stale
    ; machine position. To work around this, we can apply a delay of greater
    ; than 200ms to ensure that the machine position is updated.
    ; This value is set to 0 by default which simply waits for the movement
    ; queue to empty, but if you find that you are receiving random probe
    ; innacuracies or false triggers on protected probe moves you can try
    ; setting this value to >200. This is only relevant if you are not using
    ; RRF 3.5rc2 or later.
    G4 P{global.mosProbePositionDelay}

    ; Probing move either complete or stopped due to collision, we need to
    ; check the location of the machine to determine if the move was completed.

    ; We multiply the current position by 100 as this gives us an accuracy within
    ; 0.01mm, and then we ceil and floor the target position to give us an
    ; acceptable range - RRF will not always hit the target position exactly, but
    ; it is always close enough for our purposes.
    G6516 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }