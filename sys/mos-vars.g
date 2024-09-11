; mos-vars.g
;
; Defines internal variables that we can make safe assumptions about.

; Define global variables that are intended to be overridden by the user in mos-user-vars.g
global mosFeatToolSetter=false
global mosFeatTouchProbe=false
global mosFeatSpindleFeedback=false
global mosFeatCoolantControl=false
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
; If your machine axes move in the opposite directions, you can rename or
; reorder these options to match your machine correctly.
global mosCornerNames = {"Front Left", "Front Right", "Back Right", "Back Left"}

; Relative to the workpiece, where is the surface to be probed?
global mosSurfaceNames = {"Left","Right","Front","Back","Top"}

; Store additional tool information.
; Values are: [radius, {deflection-x, deflection-y}]
global mosET = { 0.0, {0.0, 0.0} }
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

; Stores the calculated center position in X and Y against the workplace
; index that was zeroed.
global mosDfltWPCtrPos = { null, null }
global mosWPCtrPos = { vector(limits.workplaces, global.mosDfltWPCtrPos) }

; Stores the calculated radius of the circular workpiece probed against the workplace
; index that was zeroed.
global mosDfltWPRad = null
global mosWPRad = { vector(limits.workplaces, global.mosDfltWPRad) }

; Stores the calculated dimensions of the last rectangular workpiece probed.
global mosDfltWPDims = { null, null }
global mosWPDims = { vector(limits.workplaces, global.mosDfltWPDims) }

; Stores the calculated dimensional error of the last dimensions versus
; what the operator inputted.
; This can be used to set a touch probe deflection value.
global mosDfltWPDimsErr = { null, null }
global mosWPDimsErr = { vector(limits.workplaces, global.mosDfltWPDimsErr) }

; Stores the calculated rotation of the workpiece in relation to the
; X axis. This value can be applied as a G68 rotation value to align
; the workpiece with the machine axes.
global mosDfltWPDeg = null
global mosWPDeg = { vector(limits.workplaces, global.mosDfltWPDeg) }

; This is the corner number that was picked by the
; operator for the most recent outside or inside
; corner probe.
global mosDfltWPCnrNum = null
global mosWPCnrNum = { vector(limits.workplaces, global.mosDfltWPCnrNum) }

; These are the X and Y coordinates of the most recent
; corner probe.
global mosDfltWPCnrPos = { null, null }
global mosWPCnrPos = { vector(limits.workplaces, global.mosDfltWPCnrPos) }

; This is the angle of the corner of the most recent
; outside corner probe.
global mosDfltWPCnrDeg = null
global mosWPCnrDeg = { vector(limits.workplaces, global.mosDfltWPCnrDeg) }

; This is the Co-ordinate along the chosen axis of the
; most recent single surface probe.
global mosDfltWPSfcPos = null
global mosWPSfcPos = { vector(limits.workplaces, global.mosDfltWPSfcPos) }

; This is the axis of the measurement of the most recent
; single surface probe.
global mosDfltWPSfcAxis = null
global mosWPSfcAxis = { vector(limits.workplaces, global.mosDfltWPSfcAxis) }

; Canned Cycle settings
global mosCCD = null ; Canned Cycle Drilling status

; Daemon settings
; Required for regular task updates (e.g. VSSC)
global mosDAE = true  ; Daemon Enable

global mosDAEUR = 500 ; Daemon Update Rate (ms) - do not reduce below 500

; Do not change these variables directly, use the VSSC control M-codes instead
global mosVSEnabled = false ; VSSC enabled
global mosVSOE = true       ; VSSC Override enabled
global mosVSP = 0           ; VSSC Period
global mosVSV = 0.0         ; VSSC Variance
global mosVSPT = 0          ; VSSC Previous Adjustment Time
global mosVSPS = 0.0        ; VSSC Previous Adjustment Speed

; Spindle configuration
global mosSID = null  ; Spindle ID
global mosSFCID = null ; Spindle Feedback Change ID
global mosSFSID = null ; Spindle Feedback Stop ID
global mosSAS = null  ; Spindle Acceleration (s) - feedback disabled
global mosSDS = null  ; Spindle Deceleration (s) - feedback disabled

; Toolsetter configuration
global mosTSID = null ; Toolsetter ID
global mosTSP = null  ; Toolsetter Position
global mosTSR = null  ; Toolsetter Radius
global mosTSAP = null ; Toolsetter Activation Point

; Touch probe configuration
global mosTPID = null ; Touch Probe ID
global mosTPR = null  ; Touch Probe Radius
global mosTPD = null  ; Touch Probe Deflection
global mosTPRP = null ; Touch Probe Reference Point

; Datum tool configuration
global mosDTR = null ; Datum Tool Radius

; Coolant configuration
global mosCAID = null ; Coolant Air ID
global mosCMID = null ; Coolant Mist ID
global mosCFID = null ; Coolant Flood ID

; Protected move configuration
global mosPMBO = null ; Protected Move Back Off

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

; Used during runtime to detect GPIO
; pins which have changed state.
global mosGPV = null
global mosGPD = null

; Used during runtime to track the state of
; gpOut pins.
global mosPS = { vector(limits.gpOutPorts, 0.0) }

; Tracks whether description messages have been
; displayed during this session. The first 2 indexes
; are used by the G6600 macro, the others are used by
; G6500 to G6509, one each, in order. G6520 uses mosDD[11],
; and G37.1 uses mosDD[12]. mosDD[13] is used during tool changes.
global mosDD = { vector(14, false) }

