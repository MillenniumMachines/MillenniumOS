; G6550.2.g: BACKOFF MOVE - EXECUTE
;
; During probing events, we want to use protected moves for safety.
; However, when the probe is triggered, we cannot use a protected move
; away from the surface, as the probe is already activated and stops
; instantly. Using G6550.2, we move towards the target (back-off)
; location until the probe is deactivated. We can then follow up with
; a protected move to the target location.
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

var roughSpeed   = { sensors.probes[param.I].speeds[0]   }
var fineSpeed    = { sensors.probes[param.I].speeds[1]   }
var travelSpeed  = { sensors.probes[param.I].travelSpeed }

; Use absolute positions in mm
G90
G21

; Configure probe speed
M558 K{ param.I } F{ var.travelSpeed }

; Move to position while checking probe for deactivation.
G53 G38.5 K{ param.I } X{ var.tPX } Y{ var.tPY } Z{ var.tPZ }

; Reset probe speed
M558 K{param.I} F{var.roughSpeed, var.fineSpeed}