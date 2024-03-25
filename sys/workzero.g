; workzero.g - MOVE TO ORIGIN

; Use absolute positions in mm
G90
G21
G94

; Park at top of Z
G27 Z1

if { global.mosTM }
    M291 P{"We will now move above X=0, Y=0 in WCS " ^ move.workplaceNumber+1 ^ " and then down to Z=" ^ global.mosCL ^"mm.<br/>Press <b>Continue</b> to proceed!" } R"MillenniumOS: Go to Zero " T0 S4 K{ "Continue", "Cancel" }
    if { input != 0 }
        abort { "Operator aborted move to X=0, Y=0!" }

; Move above origin
G0 X0 Y0

G0 Z{ global.mosCL }

M291 P{"Move to Z=0?<br/>Click <b>Continue</b> if you are sure the tool is " ^ global.mosCL ^ "mm above the origin, otherwise <b>Cancel</b>!" } R"MillenniumOS: Go to Zero" T0 S4 K{ "Continue", "Cancel" }
if { input != 0 }
    abort { "Operator aborted move to Z=0!" }

; Move down to Z=0 at our slowest manual probing speed.
G1 Z0 F{global.mosMPS[2]}