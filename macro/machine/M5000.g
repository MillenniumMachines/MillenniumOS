; M5000.g: RETURN MACHINE INFORMATION

; This file contains code that would be repeated often to
; return machine information, in particular the current
; position
; Return machine information

if { !exists(param.P) }
    abort { "M5011: No machine information requested with P parameter." }

if { !exists(global.mosMI) }
    global mosMI = { null }

M400

if { param.P == 0 } ; Current Absolute Co-Ordinates in all Axes
    set global.mosMI = { vector(#move.axes, null) }
    while { iterations < #move.axes }
        set global.mosMI[iterations] = { move.axes[iterations].workplaceOffsets[move.workplaceNumber] + (state.currentTool < 0 ? 0 : tools[state.currentTool].offsets[iterations]) + move.axes[iterations].userPosition }

elif { param.P == 1 && exists(param.I) && param.I >= 0 && param.I < #move.axes } ; Current Absolute Co-Ordinates in a single Axis
    set global.mosMI = { move.axes[param.I].workplaceOffsets[move.workplaceNumber] + (state.currentTool < 0 ? 0 : tools[state.currentTool].offsets[param.I]) + move.axes[param.I].userPosition }