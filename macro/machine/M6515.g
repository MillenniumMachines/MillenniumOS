; M6515.g - CHECK MACHINE LIMITS
;
; This macro checks if the given position is within the limits
; of the machine. It will trigger an abort if any of the positions
; are outside of the machine limits.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "M6515: Must provide at least one of X, Y and Z parameters!" }

; Check if target position is within machine limits
; Long lines like this suck, but RRF runs on hardware-limited
; systems. Assigning lots of variables to make this line more
; readable means we cannot use those variables in other places.
if { exists(param.X) && (param.X < move.axes[0].min || param.X > move.axes[0].max) }
    abort { "Target probe position X=" ^ param.X ^ " is outside machine limit on X axis. Reduce overtravel if probing away, or clearance if probing towards, the center of the table" }
if { exists(param.Y) && (param.Y < move.axes[1].min || param.Y > move.axes[1].max) }
    abort { "Target probe position Y=" ^ param.Y ^ " is outside machine limit on Y axis. Reduce overtravel if probing away, or clearance if probing towards, the center of the table" }
if { exists(param.Z) && (param.Z < move.axes[2].min || param.Z > move.axes[2].max) }
    abort { "Target probe position Z=" ^ param.Z ^ " is outside machine limit on Z axis." }