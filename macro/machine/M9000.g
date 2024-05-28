
if { global.mosTM && !global.mosDD[0] && param.S == 0 }
    M291 P{ "Before executing cutting operations, it is necessary to identify where the workpiece for a part is. We will do this by probing and setting a work co-ordinate system (WCS) origin point." } R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{ "The origin of a WCS is the reference point for subsequent cutting operations, and must match the chosen reference point in your CAM software." } R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{ "You will need to select an appropriate probe cycle type (or types!) based on the shape of your workpiece." } R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{ "For a square or rectangular workpiece, you should start with the <b>Vise Corner</b> probing cycle to identify your origin corner and Z height." } R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{ "For a round workpiece, you should start with the <b>Circular Boss</b> and <b>Single Surface (Z)</b> cycle to identify the center of the circle as your origin and Z height." } R"MillenniumOS: Probe Workpiece" T0 S2
    M291 P{ "<b>NOTE</b>: Surfaces are named assuming that you (the operator) are standing in front of the machine, with the Z column at the <b>BACK</b>." } R"MillenniumOS: Probe Workpiece" T0 S2

    ; If user does not have a touch probe configured,
    ; walk them through the manual probing procedure.
    if { global.mosPTID == null }
        M291 P{ "Your machine does not have a touch probe configured, so probing will involve manually jogging the machine until an installed tool or metal dowel touches the workpiece." } R"MillenniumOS: Probe Workpiece" T0 S2
        M291 P{ "You will be walked through this process so it should be relatively foolproof, but <b>it is possible to damage your tool, spindle or workpiece</b> if you press the wrong jog button!" } R"MillenniumOS: Probe Workpiece" T0 S2
    set global.mosDD[0] = true

; Display description of vise corner probe if not already displayed this session
if { global.mosTM && !global.mosDD[11] }
    M291 P"This probe cycle finds the X, Y and Z co-ordinates of the corner of a workpiece by probing the top surface and twice each along the 2 edges that form the corner." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"You will be asked to enter approximate <b>surface lengths</b> for the surfaces forming the corner, a <b>clearance distance</b> and an <b>overtravel distance</b>." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"These define how far the probe will move along the surfaces from the corner location before probing, and how far past the expected surface the probe can move before erroring if not triggered." R"MillenniumOS: Probe Vise Corner" T0 S2
    M291 P"You will then jog the tool over the corner to be probed.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Vise Corner" T0 S3
    if { result != 0 }
        abort { "Vise corner probe aborted!" }
    set global.mosDD[11] = true

; Display description of surface probe if not displayed this session
if { global.mosTM && !global.mosDD[4] }
    M291 P"This operation finds the co-ordinate of a surface on a single axis. It is usually used to find the top surface of a workpiece but can be used to find X or Y positions as well." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: This operation will only return accurate results if the surface you are probing is perpendicular to the axis you are probing in." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"You will jog the tool or touch probe to your chosen starting position. Your starting position should be outside and above X or Y surfaces, or directly above the top surface." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"MillenniumOS: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: For X or Y surfaces, the probe will move down <b>BEFORE</b> moving horizontally to detect a surface. Bear this in mind when selecting a starting position." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"For X or Y surfaces, you will then be asked for a <b>probe depth</b>. This is how far your probe will move down from the starting position before moving in X or Y." R"MillenniumOS: Probe Surface" T0 S2
    M291 P"Finally, you will be asked to set a <b>probe distance</b>. This is how far the probe will move towards a surface before returning an error if it did not trigger." R"MillenniumOS: Probe Surface" T0 S3
    if { result != 0 }
        abort { "Surface probe aborted!" }

    set global.mosDD[4] = true

; Display description of rectangle block probe if not already displayed this session
if { global.mosTM && !global.mosDD[10] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the corner of a rectangular workpiece by probing twice each along the 2 edges that form the corner." R"MillenniumOS: Probe Outside Corner " T0 S2
    M291 P"You will be asked to enter approximate <b>surface lengths</b> for the surfaces forming the corner, a <b>clearance distance</b> and an <b>overtravel distance</b>." R"MillenniumOS: Probe Outside Corner" T0 S2
    M291 P"These define how far the probe will move along the surfaces from the corner location before probing, and how far past the expected surface the probe can move before erroring if not triggered." R"MillenniumOS: Probe Outside Corner" T0 S2
    M291 P"You will then jog the tool over the corner to be probed.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Outside Corner" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards before probing towards the corner surfaces. Press <b>OK</b> to continue." R"MillenniumOS: Probe Outside Corner" T0 S3
    if { result != 0 }
        abort { "Outside corner probe aborted!" }
    set global.mosDD[10] = true

; Display description of rectangle block probe if not already displayed this session
if { global.mosTM && !global.mosDD[5] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a rectangular block (protruding feature) on a workpiece by probing towards the block surfaces from all 4 directions." R"MillenniumOS: Probe Rect. Block " T0 S2
    M291 P"You will be asked to enter an approximate <b>width</b> and <b>height</b> of the block, and a <b>clearance distance</b>." R"MillenniumOS: Probe Rect. Block" T0 S2
    M291 P"These define how far the probe will move away from the center point before moving downwards and probing back towards the relevant surfaces." R"MillenniumOS: Probe Rect. Block" T0 S2
    M291 P"You will then jog the tool over the approximate center of the block.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Rect. Block" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards before probing towards the centerpoint. Press ""OK"" to continue." R"MillenniumOS: Probe Rect. Block" T0 S3
    if { result != 0 }
        abort { "Rectangle block probe aborted!" }
    set global.mosDD[5] = true

; Display description of rectangle pocket probe if not already displayed this session
if { global.mosTM && !global.mosDD[6] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a rectangular pocket (recessed feature) on a workpiece by moving into the pocket and probing towards each surface." R"MillenniumOS: Probe Rect. Pocket " T0 S2
    M291 P"You will be asked to enter an approximate <b>width</b> and <b>height</b> of the pocket, and a <b>clearance distance</b>." R"MillenniumOS: Probe Rect. Pocket" T0 S2
    M291 P"These define how far the probe will move away from the center point before starting to probe towards the relevant surfaces." R"MillenniumOS: Probe Rect. Pocket" T0 S2
    M291 P"You will then jog the tool over the approximate center of the pocket.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Rect. Pocket" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards into the pocket before probing towards the edges. Press ""OK"" to continue." R"MillenniumOS: Probe Rect. Pocket" T0 S3
    if { result != 0 }
        abort { "Rectangle pocket probe aborted!" }
    set global.mosDD[6] = true

; Display description of boss probe if not already displayed this session
if { global.mosTM && !global.mosDD[3] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a circular boss (protruding feature) on a workpiece by probing towards the approximate center of the boss in 3 directions." R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will be asked to enter an approximate <b>boss diameter</b> and <b>clearance distance</b>.<br/>These define how far the probe will move away from the centerpoint before probing back inwards." R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will then jog the tool over the approximate center of the boss.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Boss" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards after moving outside of the boss diameter, and before probing towards the centerpoint. Press ""OK"" to continue." R"MillenniumOS: Probe Boss" T0 S3
    if { result != 0 }
        abort { "Boss probe aborted!" }
    set global.mosDD[3] = true

; Display description of bore probe if not already displayed this session
if { global.mosTM && !global.mosDD[2] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the center of a circular bore (hole) in a workpiece by moving downwards into the bore and probing outwards in 3 directions." R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will be asked to enter an approximate <b>bore diameter</b> and <b>overtravel distance</b>.<br/>These define how far the probe will move from the centerpoint, without being triggered, before erroring." R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will then jog the tool over the approximate center of the bore.<br/><b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" R"MillenniumOS: Probe Bore" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards into the bore before probing outwards. Press ""OK"" to continue." R"MillenniumOS: Probe Bore" T0 S3
    if { result != 0 }
        abort { "Bore probe aborted!" }
    set global.mosDD[2] = true
