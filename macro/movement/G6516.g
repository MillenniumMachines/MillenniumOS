; G6516.g - CHECK CURRENT POSITION MATCHES
;
; This macro checks if the given position is within the limits
; of the machine. It will trigger an abort if any of the positions
; are outside of the machine limits.
if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6516: Must provide at least one of X, Y and Z parameters!" }


if { exists(param.X) && param.X != move.axes[0].machinePosition }
    abort { "G6516: Machine position does not match expected position -  X=" ^ param.X ^ " != " ^ move.axes[0].machinePosition }

if { exists(param.Y) && param.Y != move.axes[1].machinePosition }
    abort { "G6516: Machine position does not match expected position -  Y=" ^ param.Y ^ " != " ^ move.axes[1].machinePosition }

if { exists(param.Z) && param.Z != move.axes[2].machinePosition }
    abort { "G6516: Machine position does not match expected position -  Z=" ^ param.Z ^ " != " ^ move.axes[2].machinePosition }