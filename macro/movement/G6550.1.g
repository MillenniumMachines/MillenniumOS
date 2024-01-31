; G6550.1.g: PROTECTED MOVE - EXECUTE
;
; During probing, we might make moves towards or away from a work piece
; that could collide with fixtures, clamps or the workpiece itself.
; We are, after all, relying on operator input to tell us where to move,
; and this is always a potential source of error.
; To avoid this, all moves during a probing operation should be protected,
; and executed using this command.
;
; This command behaves like a normal G1 move, except for the following changes:
;   - You must pass it a probe ID "I", which should refer to a probe that will be
;     checked during movement to detect unintended collisions.
;   - You cannot pass it a feed rate, as the feed rate is determined by the travel
;     speed set on the probe itself.
;   - Co-ordinates are absolute, in mm and machine co-ordinates only!
;
; If this command errors, it means that the probe has collided when generally
; it should not have. This is a critical failure and should stop the current job.

if { !exists(param.I) || sensors.probes[param.I].type != 8 }
    abort { "Must provide a valid probe ID (I..)!" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Make sure machine is stationary before checking machine positions
M400

; Generate target position and defaults
; Again, make sure these are accurate to 0.01mm
var tPX = { (exists(param.X)? param.X : move.axes[global.mosIX].machinePosition) }
var tPY = { (exists(param.Y)? param.Y : move.axes[global.mosIY].machinePosition) }
var tPZ = { (exists(param.Z)? param.Z : move.axes[global.mosIZ].machinePosition) }

; Check if target position is within machine limits
var mLX = { var.tPX < move.axes[global.mosIX].min || var.tPX > move.axes[global.mosIX].max }
var mLY = { var.tPY < move.axes[global.mosIY].min || var.tPY > move.axes[global.mosIY].max }
var mLZ = { var.tPZ < move.axes[global.mosIZ].min || var.tPZ > move.axes[global.mosIZ].max }

; Check if target position is within machine limits
if { var.mLX || var.mLY || var.mLZ }
    abort { "Target probe position is outside machine limits." }

var roughSpeed   = { sensors.probes[param.I].speeds[0]   }
var fineSpeed    = { sensors.probes[param.I].speeds[1]   }
var travelSpeed  = { sensors.probes[param.I].travelSpeed }

; Use absolute positions in mm
G90
G21

; Configure probe speed
M558 K{ param.I } F{ var.travelSpeed }

; Move to position while checking probe for activation
G53 G38.3 K{ param.I } X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

; Reset probe speed
M558 K{param.I} F{var.roughSpeed, var.fineSpeed}

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
var rX = { move.axes[global.mosIX].machinePosition * 100 }
var rY = { move.axes[global.mosIY].machinePosition * 100 }
var rZ = { move.axes[global.mosIZ].machinePosition * 100 }

var rFX = { floor(var.tPX * 100) }
var rFY = { floor(var.tPY * 100) }
var rFZ = { floor(var.tPZ * 100) }

var rCX = { ceil(var.tPX * 100) }
var rCY = { ceil(var.tPY * 100) }
var rCZ = { ceil(var.tPZ * 100) }

var cX = { var.rX >= var.rFX && var.rX <= var.rCX }
var cY = { var.rY >= var.rFY && var.rY <= var.rCY }
var cZ = { var.rZ >= var.rFZ && var.rZ <= var.rCZ }

if { !var.cX || !var.cY || !var.cZ }
    abort { "Protected move stopped short of target location." }

