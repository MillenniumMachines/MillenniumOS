; M6515.g: CHECK MACHINE LIMITS
;
; Aborts if the specified position is outside machine limits.
; This macro is designed to be called with axis letters as parameters.
;
; USAGE: M6515 [X<pos>] [Y<pos>] [Z<pos>] ...

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Iterate over all axes to check any provided coordinate parameters
while { iterations < #move.axes }
    var axisLetter = { move.axes[iterations].letter }
    if { exists(param[var.axisLetter]) }
        var coord = { param[var.axisLetter] }
        if { var.coord < move.axes[iterations].min || var.coord > move.axes[iterations].max }
            abort "M6515: Position " ^ var.coord ^ " for axis " ^ var.axisLetter ^ " is outside machine limits (" ^ move.axes[iterations].min ^ " to " ^ move.axes[iterations].max ^ ")"
