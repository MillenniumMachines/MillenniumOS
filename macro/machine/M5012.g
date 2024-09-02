; M5012.g - Set WCS Origin based on Probe Results
;
; Set the WCS Origin based on probe results.
; If the WCS origin is already set, prompt the operator to
; overwrite it, or average the current and probed values.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "Must provide a probed position at least one of X, Y and Z parameters!" }

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }

; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

var pdX = { move.axes[0].workplaceOffsets[var.workOffset] }
var pdY = { move.axes[1].workplaceOffsets[var.workOffset] }
var pdZ = { move.axes[2].workplaceOffsets[var.workOffset] }

if { exists(param.X) }
    if { var.pdX != 0 }
        var avgX = { (var.pdX + param.X) / 2 }
        M291 P{"WCS " ^ var.wcsNumber ^ " has existing X origin.<b>Override</b> it or <b>Average</b> with the new value?"} R"MillenniumOS: Probe Workpiece" T0 S4 K{"Override (" ^ var.pdX ^ )","Average (" ^ var.avgX ^ )" }

        if { input == 0 }
            G10 L2 P{var.wcsNumber} X{param.X}
        else
            G10 L2 P{var.wcsNumber} X{var.avgX}
    else
        G10 L2 P{var.wcsNumber} X{param.X}

if { exists(param.Y) }
    if { var.pdY != 0 }
        var avgY = { (var.pdY + param.Y) / 2 }
        M291 P{"WCS " ^ var.wcsNumber ^ " has existing Y origin.<b>Override</b> it or <b>Average</b> with the new value?"} R"MillenniumOS: Probe Workpiece" T0 S4 K{"Override (" ^ var.pdY ^ )","Average (" ^ var.avgY ^ ")" }

        if { input == 0 }
            G10 L2 P{var.wcsNumber} Y{param.Y}
        else
            G10 L2 P{var.wcsNumber} Y{var.avgY}
    else
        G10 L2 P{var.wcsNumber} Y{param.Y}

if { exists(param.Z) }
    if { var.pdZ != 0 }
        var avgZ = { (var.pdZ + param.Z) / 2 }
        M291 P{"WCS " ^ var.wcsNumber ^ " has existing Z origin.<b>Override</b> it or <b>Average</b> with the new value?"} R"MillenniumOS: Probe Workpiece" T0 S4 K{"Override (" ^ var.pdZ ^ )","Average (" ^ var.avgZ ^ ")" }

        if { input == 0 }
            G10 L2 P{var.wcsNumber} Z{param.Z}
        else
            G10 L2 P{var.wcsNumber} Z{var.avgZ}
    else
        G10 L2 P{var.wcsNumber} Z{param.Z}

echo { "WCS " ^ var.wcsNumber ^ " origin is X=" ^ move.axes[0].workplaceOffsets[var.workOffset] ^ " Y=" ^ move.axes[1].workplaceOffsets[var.workOffset] ^ " Z=" ^ move.axes[2].workplaceOffsets[var.workOffset] }