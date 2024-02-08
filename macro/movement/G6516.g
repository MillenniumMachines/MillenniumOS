; G6516.g - CHECK CURRENT POSITION MATCHES
;
; This macro checks if the given position is within the limits
; of the machine. It will trigger an abort if any of the positions
; are outside of the machine limits.
if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6516: Must provide at least one of X, Y and Z parameters!" }

; We round to 3 decimal places before comparing, as we do not restrict
; calculation accuracy in our probe macros but RRF only reports location
; to 3dp.

M400

; Check position to 2dp
var p = 100

if { exists(param.X) && (ceil(param.X*var.p) != ceil(move.axes[0].machinePosition*var.p) && floor(param.X*var.p) != floor(move.axes[0].machinePosition*var.p)) }
    abort { "G6516: Machine position does not match expected position -  X=" ^ param.X ^ " != " ^ move.axes[0].machinePosition }

if { exists(param.Y) && (ceil(param.Y*var.p) != ceil(move.axes[1].machinePosition*var.p) && floor(param.Y*var.p) != floor(move.axes[1].machinePosition*var.p)) }
    abort { "G6516: Machine position does not match expected position -  Y=" ^ param.Y ^ " != " ^ move.axes[1].machinePosition }

if { exists(param.Z) && (ceil(param.Z*var.p) != ceil(move.axes[2].machinePosition*var.p) && floor(param.Z*var.p) != floor(move.axes[2].machinePosition*var.p)) }
    abort { "G6516: Machine position does not match expected position -  Z=" ^ param.Z ^ " != " ^ move.axes[2].machinePosition }