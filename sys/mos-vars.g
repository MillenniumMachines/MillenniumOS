; mos-vars.g
;
; Defines internal variables that we can make safe assumptions about.

; Define global variables that are intended to be overridden by the user in mos-user-vars.g
global mosFeatToolSetter=false
global mosFeatTouchProbe=false
global mosFeatSpindleFeedback=false
global mosFeatVSSC=true

; Expert mode skips certain operator confirmation checks during tool changes and probing operations.
; Anything deemed to be safety critical is still executed, but the operator will not be prompted to
; confirm completed tool changes, or starting probe operations.
global mosEM=false

; Tutorial mode explains in detail the operation of a probe or tool change operation prior to the
; actual operation being executed. This is useful for those new to machining who might need a little
; more guidance before feeling happy pushing 'the button'.
global mosTM=true

; Debut mode emits additional debug information during usage.
global mosDebug=false

; Define variables that are used internally by MOS macros.
; These can be overridden in mos-user-vars.g if necessary (but almost certainly do not need to be).

; Relative to the operator, where is the corner to be probed?
; This is a global because it is used by both G6520 and G6508
global mosCnr = {"Front Left", "Front Right", "Back Right", "Back Left"}

; Store additional tool information.
; Values are: [radius, {deflection-x, deflection-y}]
global mosET = { 0.0, null }
global mosTT = { vector(limits.tools, global.mosET) }

; State of current tool change operation.
; Tool Change States:
; 0 - tfree started
; 1 - tfree completed
; 2 - tpre started
; 3 - tpre completed
; 4 - tpost started
; null - tool change complete
global mosTCS = null


; Coordinates returned by the most recent probing operation.
global mosPCX = null
global mosPCY = null
global mosPCZ = null

; Variance of most recent probe
global mosPVX = null
global mosPVY = null
global mosPVZ = null


; Clearance distance in mm. This is a static number that
; we add to operator-provided values to make sure we can
; move down to a probing location before starting the probing
; move. When probing a circular boss, a 10mm clearance value
; on a 10mm diameter boss will move the tool outwards from
; the approximate center by 15mm before dropping to the probing
; height and probing inwards towards the center.
global mosCL=10.0

; Overtravel distance in mm. This is a static number that
; we add to operator-provided values to make sure that if
; the operator has provided a slightly low estimate of the sizes
; of a workpiece or feature to probe, we will still end up triggering
; it. This value should be kept low so that if the probe does not
; activate for any reason, the electronics in the probe itself will
; hopefully not be damaged or the probe itself bent.
global mosOT=2.0

; The maximum angle in degrees that is deemed to be a square
; corner or parallel surface. Surfaces or corners that are
; not within this threshold will be considered to be non-parallel
; or perpendicular.
global mosAngleTol=0.2

; Stores the calculated center position in X and Y of the last workpiece probed.
; If this is used to probe a feature of the workpiece rather than the
; whole workpiece itself, then this will refer to the center of the
; _feature_. For example, if you probe a circular boss, this will be
; the center of the boss, which is not necessarily the center of the
; workpiece.
; When writing macros that implement cutting moves, it is very important
; to remember this distinction, and make sure that the operator has
; been made aware of this when probing for a cutting macro.
global mosWPCtrPos = { null, null }

; Stores the calculated radius of the last circular workpiece probed.
global mosWPRad = null

; Stores the calculated dimensions of the last rectangular workpiece probed.
global mosWPDims = { null, null }

; Stores the calculated dimensional error of the last dimensions versus
; what the operator inputted.
; This can be used to set a touch probe deflection value.
global mosWPDimsErr = { null, null }

; Stores the calculated rotation of the workpiece in relation to the
; X axis. This value can be applied as a G68 rotation value to align
; the workpiece with the machine axes.
global mosWPDeg = null

; This is the corner number that was picked by the
; operator for the most recent outside or inside
; corner probe.
global mosWPCnrNum = null

; These are the X and Y coordinates of the most recent
; corner probe.
global mosWPCnrPos = { null, null }

; This is the angle of the corner of the most recent
; outside corner probe.
global mosWPCnrDeg = { null, null }

; This is the Co-ordinate along the chosen axis of the
; most recent single surface probe
global mosWPSfcPos = null

; This is the axis along which the most recent single
global mosWPSfcAxis = null

; Daemon settings
; Required for regular task updates (e.g. VSSC)
global mosDAE = true

global mosDAEUR = 500  ; Re-trigger background tasks every 500ms
                                  ; don't reduce this below 500!

; Do not change these variables directly, use the VSSC control M-codes instead
global mosVSEnabled = false
global mosVSOE = true
global mosVSP = 0
global mosVSV = 0.0
global mosVSPT = 0
global mosVSPS = 0.0

; Spindle configuration
global mosSID = null
global mosSAS = null
global mosSDS = null

; Toolsetter configuration
global mosTSID = null
global mosTSP = null
global mosTSAP = null

; Touch probe configuration
global mosTPID = null
global mosTPR = null
global mosTPD = null
global mosTPRP = null

; Datum tool configuration
global mosDTR = null

; Protected move configuration
global mosPMBO = null

; Manual probing feed rates - travel, rough, fine
global mosMPS = { 1200, 300, 60 }

; Manual probing back off
global mosMPBO = 5

; Manual probing distance names
global mosMPDN = { "50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "Finish", "Back-Off 1mm" }

; Manual probing distance values
global mosMPD  = { 50, 10, 5, 1, 0.1, 0.01, 0, -1 }

; Manual probing slow speed index
global mosMPSI = 3

; The last tool in the table is used for probing
; operations. It is either a dedicated touch probe,
; or a datum tool (which can be a gauge pin,
; a dowel or a flat endmill). Importantly, it
; stores a tool radius which is used to apply
; compensation during probing.
global mosPTID = { limits.tools - 1 }

; Used during configuration to detect
; probes.
global mosDPID = null

; Used during runtime to indicate a
; specific probe ID has been detected.
global mosPD = null

; Tracks whether description messages have been
; displayed during this session. The first 2 indexes
; are used by the G6600 macro, the others are used by
; G6500 to G6509, one each, in order. G6520 uses mosDD11,
; and G37.1 uses the last index.
global mosDD0 = false
global mosDD1 = false
global mosDD2 = false
global mosDD3 = false
global mosDD4 = false
global mosDD5 = false
global mosDD6 = false
global mosDD7 = false
global mosDD8 = false
global mosDD9 = false
global mosDD10 = false
global mosDD11 = false
global mosDD12 = false
