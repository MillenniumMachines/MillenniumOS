; G6512.g: SINGLE SURFACE PROBE - EXECUTE MANUALLY
;
; Surface probe in any direction.
;
; This macro is designed to be called directly with parameters set. To gather
; parameters from the user, use the G6510 macro which will prompt the operator
; for the required parameters.

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6512: Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; Make sure machine is stationary before checking machine positions
M400

; Assume current location is start point.
var sX = { move.axes[0].machinePosition }
var sY = { move.axes[1].machinePosition }
var sZ = { move.axes[2].machinePosition }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.
var tPX = { exists(param.X)? param.X : var.sX }
var tPY = { exists(param.Y)? param.Y : var.sY }
var tPZ = { exists(param.Z)? param.Z : var.sZ }

; Successively approach target position until operator is happy that there is contact.
; We choose the increments based on the distance to the target position.

var distanceNames = { "50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "0.001mm", "Finish" }
var distances     = { 50, 10, 5, 1, 0.1, 0.01, 0.001, 0 }

; This is the index of the speed in the distances array to switch to fine probing speed
var slowSpeed     = 3

var curPos = { var.sX, var.sY, var.sZ }
while { true }

    ; Distance between current position and target in each axis
    var dX = { var.curPos[0] - var.tPX }
    var dY = { var.curPos[1] - var.tPY }
    var dZ = { var.curPos[2] - var.tPZ }

    if { var.dX == 0 && var.dY == 0 && var.dZ == 0 }
        abort { "Reached target position without operator selecting Finish!" }

    ; Calculate the magnitude of the direction vector
    var mag = { sqrt(pow(var.dX, 2) + pow(var.dY, 2) + pow(var.dZ, 2)) }

    ; Calculate straight-line distance to target
    var dist = { sqrt(pow(var.dX, 2) + pow(var.dY, 2) + pow(var.dZ, 2)) }

    ; Find the v distances less than the distance to the target
    var vDistCount = null
    var vDists = null
    var vDistNames = null
    var seenvDists = false
    var vDistIndex = 0
    var slowSpeedIndex = null

    M7500 S{"Distance to target: " ^ var.dist}

    ; Calculate the v distances
    while { iterations < #var.distances }
        ; If the distance of a step is less than the distance to the target,
        ; then it is v.
        ; If the distance is v, then all subsequent distances are also v.
        ; We should build a list of v distances and their names
        if { var.distances[iterations] < var.dist }
            if { !var.seenvDists }
                set var.vDistIndex = { iterations }
                ; The number of v distances is the total number of distances
                ; minus the number of iterations before seeing a v distance.
                set var.vDistCount = { #var.distances - iterations }
                ; With a v distanceCount, we can instantiate new lists for
                ; v distances and v distance names.
                set var.vDists = { vector(var.vDistCount, 0) }
                set var.vDistNames = { vector(var.vDistCount, "Unknown") }

                ; Only run the above when seeing the first v distance
                set var.seenvDists = true

            ; Append the v distance to the list of v distances
            set var.vDists[iterations - var.vDistIndex] = { var.distances[iterations] }
            set var.vDistNames[iterations - var.vDistIndex] = { var.distanceNames[iterations] }



    ; Calculate the index where we switch to slow speed.
    set var.slowSpeedIndex = { var.slowSpeed - (#var.distances - var.vDistCount) }

    var pX = { var.curPos[0] }
    var pY = { var.curPos[1] }
    var pZ = { var.curPos[2] }

    M291 P{"Current Position: X=" ^ var.pX ^ " Y=" ^ var.pY ^ " Z=" ^ var.pZ ^ "<br/>Expected Distance to target: " ^ var.dist ^ "mm.<br/>Select distance to move towards target."} R"MillenniumOS: Manual Probe" S4 K{ var.vDistNames } D{var.vDistCount} T0 J1

    if { result != 0 }
        abort { "Operator cancelled probing!" }

    var dI = { input }

    M7500 S{"Selected distance index: " ^ var.dI}

    if { var.dI < 0 || var.dI > #var.vDistNames }
        abort { "Invalid distance selected!" }

    ; Otherwise, pick the operator selected distance
    var dD = { var.vDists[var.dI] }

    if { var.dD == 0 }
        M7500 S{"Operator indicated that surface is being touched by tool"}
        break

    ; Use a lower movement speed for the smallest increments
    var moveSpeed = { (var.dI >= var.slowSpeedIndex) ? global.mosManualProbeSpeedFine : global.mosManualProbeSpeedApproach }

    ; Generate the new position based on the increment chosen
    var nPX = { var.curPos[0] - ((var.dX / var.mag) * var.dD) }
    var nPY = { var.curPos[1] - ((var.dY / var.mag) * var.dD) }
    var nPZ = { var.curPos[2] - ((var.dZ / var.mag) * var.dD) }

    ; Move towards probe point in increment chosen by operator
    G53 G1 X{ var.nPX } Y{ var.nPY } Z{ var.nPZ } F{var.moveSpeed}

    ; Wait for all moves in the queue to finish
    M400

    ; Update the current position
    set var.curPos = { move.axes[0].machinePosition, move.axes[1].machinePosition, move.axes[2].machinePosition }

; Set the probe coordinates to the current position
set global.mosProbeCoordinate = var.curPos

; Probe variance makes no sense for manual probes that are done once
set global.mosProbeVariance = { 0 }

; Calculate distance between start and current position
var dX = { var.sX - var.curPos[0] }
var dY = { var.sY - var.curPos[1] }
var dZ = { var.sZ - var.curPos[2] }

; Calculate back-off normal
var bN = { sqrt(pow(var.dX, 2) + pow(var.dY, 2) + pow(var.dZ, 2)) }

; Calculate normalized direction and backoff,
; apply to current position.
var bPX = { var.curPos[0] + (var.dX / var.bN * global.mosManualProbeBackoff) }
var bPY = { var.curPos[1] + (var.dY / var.bN * global.mosManualProbeBackoff) }
var bPZ = { var.curPos[2] + (var.dZ / var.bN * global.mosManualProbeBackoff) }

G6550 X{ var.bPX } Y{ var.bPY } Z{ var.bPZ }

; Wait for all moves in the queue to finish
M400
