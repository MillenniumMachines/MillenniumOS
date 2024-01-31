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

; Store additional tool information.
global mosToolTable = { vector(limits.tools, { null, false, {0, 0} }) }

; Coordinates returned by the most recent probing operation.
global mosProbeCoordinate={ null, null, null }
global mosProbeVariance={ null, null, null }

global mosProbeOvertravel=2.0 ; Overtravel distance in mm

; Delay in ms after probing operation completes before recording position.
; Do not override this unless you are seeing false protected move triggers
; as otherwise it will just slow down all probing operations.
global mosProbePositionDelay=0

; These store the X and Y co-ordinates of the center
; of the most recent bore probe.
global mosBoreCenterPos = {null, null}

; And the calculated radius of the bore
global mosBoreRadius = null

; These are the X and Y coordinates of the center
; of the most recent rectangular pocket probe.
global mosRectanglePocketCenterPos = {null, null}

; And the calculated dimensions in mm, of the
; most recent rectangular pocket probe.
global mosRectanglePocketDimensions = {null, null}

; These are the X and Y coordinates of the center
; of the most recent rectangle block probe.
global mosRectangleBlockCenterPos = {null, null}

; These are the calculated dimensions, in mm, of the
; most recent rectangle block probe.
global mosRectangleBlockDimensions = {null, null}

; When probing an outside corner, move inwards by
; this distance in mm for the initial probe.
global mosOutsideCornerDefaultDistance = 10.0

; This is the corner number that was picked by the
; operator for the most recent outside corner probe
global mosOutsideCornerNum = null

; These are the X and Y coordinates of the most recent
; outside corner probe.
global mosOutsideCornerPos = {null, null}

; This is the corner number that was picked by the
; operator for the most recent inside corner probe
global mosInsideCornerNum = null

; These are the X and Y coordinates of the most recent
; inside corner probe.
global mosInsideCornerPos = {null, null}

; This is the Co-ordinate along the chosen axis of the
; most recent single surface probe
global mosSurfacePos = null
global mosSurfaceAxis = null


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

; Define constants for axis indices and names
global mosIX                = 0
global mosIY                = 1
global mosIZ                = 2
global mosN                 = {"X","Y","Z"}

; Define constants for probe types
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

; Used during configuration to detect
; probes.
global mosDetectedProbeID = null

; Used during runtime to indicate a
; specific probe ID has been detected.
global mosProbeDetected = {vector(limits.zProbes, false)}

; Touch probe tool ID
global mosTouchProbeToolID = null

; Last canned probe cycle executed
global mosLastProbeCycle = null

global mosDescProbeWorkpieceDisplayed = false
global mosDescBoreDisplayed           = false
global mosDescSurfaceDisplayed        = false
global mosDescOutsideCornerDisplayed  = false