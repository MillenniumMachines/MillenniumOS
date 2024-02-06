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

M7500 S{"Unprotected move to X=" ^ var.tPX ^ " Y=" ^ var.tPY ^ " Z=" ^ var.tPZ ^ " as touch probe is not available."}
G53 G1 X{ var.tPX } Y{ var.tPY } Z{ var.tPZ } F{ global.mosManualProbeSpeed[0] }
M400
