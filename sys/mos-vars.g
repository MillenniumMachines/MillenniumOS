; mos-vars.g
;
; Defines internal variables that we can make safe assumptions about.

; Define global variables that are intended to be overridden by the user in mos-user-vars.g
global mosFeatureToolSetter=false
global mosFeatureTouchProbe=false
global mosFeatureSpindleFeedback=false
global mosFeatureVSSC=true

; Expert mode skips descriptor steps during tool changes and probing operations. It does not skip
; safety checks, but assumes the operator knows how the probing operation they are performing works.
global mosExpertMode=false

; Debut mode emits additional debug information during usage.
global mosDebug=false

; Define variables that are used internally by MOS macros.
; These can be overridden in mos-user-vars.g if necessary (but almost certainly do not need to be).

; Define names for corner identities. The corner ID is the index into these arrays, plus 1.
global mosOriginCorners={"Front Left","Front Right","Rear Right","Rear Left"}
global mosOriginAll={"Front Left","Front Right","Rear Right","Rear Left","Center"}

; Define names for work offsets. The work offset ID is the index into these arrays.
; None means do not set origins on a work offset.
global mosWorkOffsetCodes={"None","G54","G55","G56","G57","G58","G59","G59.1","G59.2","G59.3"}

;global mosProbeCycleNames = {"Vise Corner (X,Y,Z)", "Circular Bore (X,Y)", "Circular Boss (X,Y)", "Rectangle Pocket (X,Y)", "Rectangle Boss (X,Y)", "Outside Corner (X,Y)", "Single Surface (X/Y/Z)" }
global mosProbeCycleNames = { "Vise Corner (X,Y,Z)", "Circular Bore (X,Y)", "Circular Boss (X,Y)", "Rectangle Block (X,Y)", "Single Surface (X/Y/Z)" }

; Friendly names to indicate the location of a surface to be probed, relative to the tool.
; Left means 'surface is to the left of the tool', i.e. we will move the table towards the
; _right_ to probe it.
; If your machine is configured with the axes in a different orientation, you can override
; these names in mos-user-vars.g but there is no way to override the "Below" option (which)
; is a Z axis, and always probes towards Z minimum. On the Milo, Z Max is 0 and Z min is 60 or 120.
global mosSurfaceLocationNames = {"Left","Right","In Front","Behind","Below"}

; Relative to the tool, where is the corner to be probed?
global mosOutsideCornerNames = {"Behind, Right","Behind, Left","In Front, Right","In Front, Left"}

global mosTouchProbeToolName = "Touch Probe"
global mosDatumToolName = "Datum Tool"

; Store additional tool information.
; Values are: [radius, inToolChanger, toolChangerPos]
global mosEmptyTool = { 0.0, false, {0, 0} }
global mosToolTable = { vector(limits.tools, global.mosEmptyTool) }

; Coordinates returned by the most recent probing operation.
global mosProbeCoordinate={ null, null, null }
global mosProbeVariance={ null, null, null }

; Clearance distance in mm. This is a static number that
; we add to operator-provided values to make sure we can
; move down to a probing location before starting the probing
; move. When probing a circular boss, a 10mm clearance value
; on a 10mm diameter boss will move the tool outwards from
; the approximate center by 15mm before dropping to the probing
; height and probing inwards towards the center.
global mosProbeClearance=10.0

; Overtravel distance in mm. This is a static number that
; we add to operator-provided values to make sure that if
; the operator has provided a slightly low estimate of the sizes
; of a workpiece or feature to probe, we will still end up triggering
; it. This value should be kept low so that if the probe does not
; activate for any reason, the electronics in the probe itself will
; hopefully not be damaged or the probe itself bent.
global mosProbeOvertravel=2.0

; The maximum angle in degrees that is deemed to be a square
; corner or parallel surface. Surfaces or corners that are
; not within this threshold will be considered to be non-parallel
; or perpendicular.
global mosProbeSquareAngleThreshold=0.1

; Delay in ms after probing operation completes before recording position.
; Do not override this unless you are seeing false protected move triggers
; as otherwise it will just slow down all probing operations.
global mosProbePositionDelay=0

; Stores the calculated center position in X and Y of the last workpiece probed.
; If this is used to probe a feature of the workpiece rather than the
; whole workpiece itself, then this will refer to the center of the
; _feature_. For example, if you probe a circular boss, this will be
; the center of the boss, which is not necessarily the center of the
; workpiece.
; When writing macros that implement cutting moves, it is very important
; to remember this distinction, and make sure that the operator has
; been made aware of this when probing for a cutting macro.
global mosWorkPieceCenterPos = { null, null }

; Stores the calculated radius of the last circular workpiece probed.
global mosWorkPieceRadius = null

; Stores the calculated dimensions of the last rectangular workpiece probed.
global mosWorkPieceDimensions = { null, null }

; Stores the calculated rotation of the workpiece in relation to the
; X axis. This value can be applied as a G68 rotation value to align
; the workpiece with the machine axes.
global mosWorkPieceRotationAngle = null


; Stores the calculated bounding box of the last workpiece probed.
; in X and Y dimensions. Each entry is a min, max pair for X and
; Y dimensions respectively.
global mosWorkPieceBoundingBox = { {null, null}, {null, null}}

; This is the corner number that was picked by the
; operator for the most recent outside or inside
; corner probe.
global mosWorkPieceCornerNum = null

; These are the X and Y coordinates of the most recent
; corner probe.
global mosWorkPieceCornerPos = {null, null}

; When probing a corner, move inwards by
; this distance in mm for the initial probe.
global mosOutsideCornerDefaultDistance = 10.0


; These are the angles of the X and Y surfaces of the
; most recent outside corner probe.
global mosWorkPieceCornerSurfaceAngle = {null, null}

; This is the angle of the corner of the most recent
; outside corner probe.
global mosWorkPieceCornerAngle = null

; This is the Co-ordinate along the chosen axis of the
; most recent single surface probe
global mosWorkPieceSurfacePos = null

; This is the axis along which the most recent single
global mosWorkPieceSurfaceAxis = null


; Daemon settings
; Required for regular task updates (e.g. VSSC)
global mosDaemonEnable = true

global mosDaemonUpdateRate = 500  ; Re-trigger background tasks every 500ms
                                  ; don't reduce this below 500!

; Variable Spindle Speed Control settings
global mosVsscDebug = false ; Whether to emit debug information

; Do not change these variables directly, use the VSSC control M-codes instead
global mosVsscEnabled = false
global mosVsscOverrideEnabled = true
global mosVsscPeriod = 0
global mosVsscVariance = 0.0
global mosVsscSpeedWarningIssued = false
global mosVsscPreviousAdjustmentTime = 0
global mosVsscPreviousAdjustmentRPM = 0.0

; Define constants for wizard configured settings
global mosSpindleID = null
global mosSpindleAccelSeconds = null
global mosSpindleDecelSeconds = null
global mosTouchProbeID = null
global mosToolSetterID = null
global mosToolSetterPos = null
global mosToolSetterActivationPos = null
global mosTouchProbeRadius = null
global mosTouchProbeDeflection = null
global mosTouchProbeReferencePos = null
global mosDatumToolRadius = null

global mosManualProbeSpeed = { 1200, 300, 60 }
global mosManualProbeBackoff=5

; The last tool in the table is used for probing
; operations. It is either a dedicated touch probe,
; or a datum tool (which can be a gauge pin,
; a dowel or a flat endmill). Importantly, it
; stores a tool radius which is used to apply
; compensation during probing.
global mosProbeToolID = { limits.tools - 1 }

; Used during configuration to detect
; probes.
global mosDetectedProbeID = null

; Used during runtime to indicate a
; specific probe ID has been detected.
global mosProbeDetected = {vector(limits.zProbes, false)}

; Last canned probe cycle executed
global mosLastProbeCycle = null

global mosDescDisplayed = { vector(9, false) }