; G6512.g: SINGLE SURFACE PROBE - EXECUTE MANUALLY
;
; Surface probe in any direction.
;
; This macro is designed to be called directly with parameters set. To gather
; parameters from the user, use the G6510 macro which will prompt the operator
; for the required parameters.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Make sure we're in the default motion system
M598

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

; Our target positions do not take probe tool radius
; into account on the X and Y axes. We need to account
; for this so that when say, we move to a position that
; should be 10mm away from the target, we actually move
; the edge of the tool 10mm away from the target rather
; than the center. This becomes important if

; Successively approach target position until operator is happy that there is contact.
; We choose the increments based on the distance to the target position.

var distanceNames = { "50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "Finish", "Back-Off 1mm" }
var distances     = { 50, 10, 5, 1, 0.1, 0.01, 0, -1 }

; This is the index of the speed in the distances array to switch to fine probing speed
var slowSpeed     = 3

; Current position - shortened to cP to reduce command length!
var cP = { var.sX, var.sY, var.sZ }

while { true }
    ; Distance between current position and target in each axis
    var dX = { var.cP[0] - var.tPX }
    var dY = { var.cP[1] - var.tPY }
    var dZ = { var.cP[2] - var.tPZ }

    if { var.dX == 0 && var.dY == 0 && var.dZ == 0 }
        abort { "Reached target position without operator selecting Finish!" }

    ; Calculate the magnitude of the direction vector
    var mag = { sqrt(pow(var.dX, 2) + pow(var.dY, 2) + pow(var.dZ, 2)) }

    ; Calculate straight-line distance to target, round to 3dp
    var dist = { floor(sqrt(pow(var.dX, 2) + pow(var.dY, 2) + pow(var.dZ, 2))*1000)/1000 }

    ; Find the v distances less than the distance to the target
    var vDistC = null
    var vD = null
    var vDistN = null
    var seenvDists = false
    var vDistIndex = 0
    var slowSpeedIndex = null

    ; Commented due to memory limitations
    ; M7500 S{ "Distance to target: " ^ var.dist }

    ; Calculate the v distances
    while { iterations < #var.distances }
        ; If the distance of a step is less than the distance to the target,
        ; then it is valid.
        ; If the distance is valid, then all subsequent distances are also
        ; valid.
        ; We build a list of valid distances and their names to show to the
        ; operator.
        if { var.distances[iterations] < var.dist }
            if { !var.seenvDists }
                set var.vDistIndex = { iterations }
                ; The number of v distances is the total number of distances
                ; minus the number of iterations before seeing a valid distance.
                set var.vDistC = { #var.distances - iterations }
                ; With a valid distanceCount, we can instantiate new lists for
                ; valid distances and valid distance names.
                set var.vD = { vector(var.vDistC, 0) }
                set var.vDistN = { vector(var.vDistC+1, "Unknown") }

                ; Only run the above when seeing the first valid distance
                set var.seenvDists = true

            ; Append the valid distance to the list of valid distances
            set var.vD[iterations - var.vDistIndex] = { var.distances[iterations] }
            set var.vDistN[iterations - var.vDistIndex] = { var.distanceNames[iterations] }


    ; Add cancel button
    set var.vDistN[#var.vDistN-1] = "Cancel"

    ; Calculate the index where we switch to slow speed.
    set var.slowSpeedIndex = { var.slowSpeed - (#var.distances - var.vDistC) }

    ; Ask operator to select a distance to move towards the target point.
    M291 P{"Position: X=" ^ var.cP[0] ^ " Y=" ^ var.cP[1] ^ " Z=" ^ var.cP[2] ^ "<br/>Distance to target: " ^ var.dist ^ "mm.<br/>Select distance to move towards target."} R"MillenniumOS: Manual Probe" S4 K{ var.vDistN } D{var.vDistC} T0
    if { result != 0 || input == (#var.vDistN-1) }
        abort { "Operator cancelled probing!" }

    var dI = { input }

    ; Commented due to memory limitations
    ; M7500 S{"Selected distance index: " ^ var.dI}

    ; Validate selected distance
    if { var.dI < 0 || var.dI >= (#var.vDistN-1) }
        abort { "Invalid distance selected!" }

    ; Otherwise, pick the operator selected distance
    var dD = { var.vD[var.dI] }

    ; Break if operator picks the 'zero' distance.
    if { var.dD == 0 }
        ; Commented due to memory limitations
    ; M7500 S{"Operator indicated that surface is being touched by tool."}
        break

    if { var.dD == -1 }
        ; Commented due to memory limitations
    ; M7500 S{"Operator indicated that probe needs to be backed away from the surface."}

    ; Use a lower movement speed for the smallest increments
    var moveSpeed = { (var.dI >= var.slowSpeedIndex) ? global.mosManualProbeSpeed[2] : global.mosManualProbeSpeed[1] }

    ; Generate the new position based on the increment chosen
    var nPX = { var.cP[0] - ((var.dX / var.mag) * var.dD) }
    var nPY = { var.cP[1] - ((var.dY / var.mag) * var.dD) }
    var nPZ = { var.cP[2] - ((var.dZ / var.mag) * var.dD) }

    ; Move towards (or away from) the target point in increment chosen by operator
    G53 G1 X{ var.nPX } Y{ var.nPY } Z{ var.nPZ } F{var.moveSpeed}

    ; Wait for all moves in the queue to finish
    M400

    ; Update the current position
    set var.cP = { move.axes[0].machinePosition, move.axes[1].machinePosition, move.axes[2].machinePosition }

; Set the probe coordinates to the current position
set global.mosProbeCoordinate = { var.cP }

; Commented due to memory limitations
; M7500 S{"Probe coordinate: X=" ^ var.cP[0] ^ " Y=" ^ var.cP[1] ^ " Z=" ^ var.cP[2]}

; Probe variance makes no sense for manual probes that are done once
set global.mosProbeVariance = { 0 }

; Calculate back-off normal
var bN = { sqrt(pow(var.sX - var.cP[0], 2) + pow(var.sY - var.cP[1], 2) + pow(var.sZ - var.cP[2], 2)) }

; In some cases, our back-off distance might be higher than
; the distance we've travelled from the starting location.
; In this case, we should travel back to the starting location
; instead, because otherwise we risk crashing into things (like
; the other side of a bore that we just probed).
; If the backoff distance is higher than the normal from from the
; starting location, then we use the normal as the backoff distance.
; This is essentially the same as multiplying var.d{X,Y,Z} by 1.

; Calculate normalized direction and backoff per axis,
; and apply to current position.
var bPX = { var.cP[0] + ((var.sX - var.cP[0]) / var.bN * ((global.mosManualProbeBackoff > var.bN) ? var.bN : global.mosManualProbeBackoff)) }
var bPY = { var.cP[1] + ((var.sY - var.cP[1]) / var.bN * ((global.mosManualProbeBackoff > var.bN) ? var.bN : global.mosManualProbeBackoff)) }
var bPZ = { var.cP[2] + ((var.sZ - var.cP[2]) / var.bN * ((global.mosManualProbeBackoff > var.bN) ? var.bN : global.mosManualProbeBackoff)) }

G6550 X{ var.bPX } Y{ var.bPY } Z{ var.bPZ }

; Wait for all moves in the queue to finish
M400
