; continuous-movement.g
;
; This macro is used to continuously move the machine
; at a particular percentage of the maximum speed.
; When the machine is put into continuous movement mode
; using G95, we will enter a hotloop within this file.

; The hotloop will fire off constant movement commands when
; movement is requested and will stop instantly when
; movement is no longer requested.

; global.mosCMR is an array that holds a 1, 0 or -1 for each axis
; that is requested to move. 1 is forward, 0 is stop, -1 is reverse.

; Do not hotloop if continuous movement is disabled
; or if any of the axes are not homed.
if { !global.mosCM }
    M99

if { !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed }
    echo { "Must home all axes before enabling continuous movement!" }
    M99

set global.mosCMA = { true }

echo { "Continuous movement enabled" }

var maxF = { max(move.axes[0].speed, move.axes[1].speed, move.axes[2].speed) }
var minC = { move.axes[0].min, move.axes[1].min, move.axes[2].min }
var maxC = { move.axes[0].max, move.axes[1].max, move.axes[2].max }

var queueLen = { move.queue[0].length }

; Set queue length to 1 and with zero grace period so we don't queue a ton of moves.
M595 P1 R0 Q0

G91
G21
G94

var step = { exists(global.mosCMS) ? global.mosCMS : 0.1 }

; Calculate how long in milliseconds it will take to move the step distance
; maxF is in mm/min, so we need to convert it to mm/s by dividing by 60.
var stepTime = { var.step / (var.maxF / 60) * 1000 }

while { global.mosCM }
    ; global.mosCMR is a distance to move towards a location on each axis.
    ; For each cycle of the loop, move towards the requested location and
    ; subtract the step from the distance we still have to move.
    ; Make step amount positive or negative based on the sign of the distance.


    var mX = { (global.mosCMR[0] == 0) ? 0 : ((global.mosCMR[0] > 0) ? 1 : -1) * var.step }
    var mY = { (global.mosCMR[1] == 0) ? 0 : ((global.mosCMR[1] > 0) ? 1 : -1) * var.step }
    var mZ = { (global.mosCMR[2] == 0) ? 0 : ((global.mosCMR[2] > 0) ? 1 : -1) * var.step }

    G1 X{var.mX} Y{var.mY} F{var.maxF * global.mosCMFM}

    set global.mosCMR = { (abs(global.mosCMR[0]) > abs(var.mX)) ? (global.mosCMR[0] - var.mX) : 0, (abs(global.mosCMR[1]) > abs(var.mY)) ? (global.mosCMR[1] - var.mY) : 0, global.mosCMR[2] }
    G4 P{var.stepTime}

M595 P{var.queueLen} Q0

set global.mosCMA = false
set global.mosCM = false

echo { "Continuous movement disabled" }