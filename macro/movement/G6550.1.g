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

if { !exists(param.I) || sensors.probes[param.I].type != 8 }
    abort { "Must provide a valid probe ID (I..)!" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Generate target position and defaults
var tPX = { exists(param.X)? param.X : move.axes[global.mosIX].machinePosition }
var tPY = { exists(param.Y)? param.Y : move.axes[global.mosIY].machinePosition }
var tPZ = { exists(param.Z)? param.Z : move.axes[global.mosIZ].machinePosition }

; Check if target position is within machine limits
var mLX = { var.tPX < move.axes[global.mosIX].min || var.tPX > move.axes[global.mosIX].max }
var mLY = { var.tPY < move.axes[global.mosIY].min || var.tPY > move.axes[global.mosIY].max }
var mLZ = { var.tPZ < move.axes[global.mosIZ].min || var.tPZ > move.axes[global.mosIZ].max }

; Check if target position is within machine limits
if { var.mLX || var.mLY || var.mLZ }
    abort { "Target probe position is outside machine limits." }

echo { "Protected move to X " ^ var.tPX ^ " Y " ^ var.tPY ^ " Z " ^ var.tPZ }

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

G4 P300

; Probing move either complete or stopped due to collision, we need to
; check the location of the machine to determine if the move was completed.
; We multiply by 100 and run ceil() as this gives us an accuracy within
; 0.01mm, and either through G38.3 returning before the machine has finished
; moving, or floating point errors, this allows us to assume we're "close enough"
; to the target position to consider the move complete.
var rX = { ceil(move.axes[global.mosIX].machinePosition * 10) }
var rY = { ceil(move.axes[global.mosIY].machinePosition * 10) }
var rZ = { ceil(move.axes[global.mosIZ].machinePosition * 10) }
var rTX = { ceil(var.tPX*10) }
var rTY = { ceil(var.tPY*10) }
var rTZ = { ceil(var.tPZ*10) }

var cX = { var.rX == var.rTX }
var cY = { var.rY == var.rTY }
var cZ = { var.rZ == var.rTZ }

if { !var.cX || !var.cY || !var.cZ }
    echo { var.rX, var.rTX, var.cX }
    echo { var.rY, var.rTY, var.cY }
    echo { var.rZ, var.rTZ, var.cZ }

    abort { "Protected move stopped due to collision!" }
