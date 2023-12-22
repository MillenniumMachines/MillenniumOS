; mos-vars.g
;
; Defines internal variables that we can make safe assumptions about.

; Define global variables that are intended to be overridden by the user in mos-user-vars.g
global mosFeatureToolSetter=false
global mosFeatureTouchProbe=false
global mosFeatureVSSC=true

; Expert mode skips descriptor steps during tool changes and probing operations. It does not skip
; safety checks, but assumes the operator knows how the probing operation they are performing works.
global mosExpertMode=false

; Define variables that are used internally by MOS macros.
; These can be overridden in mos-user-vars.g if necessary (but almost certainly do not need to be).

; Define names for corner identities. The corner ID is the index into these arrays, plus 1.
global mosOriginCorners={"Front Left","Front Right","Rear Right","Rear Left"}
global mosOriginAll={"Front Left","Front Right","Rear Right","Rear Left","Centre"}

; Define names for work offsets. The work offset ID is the index into these arrays, plus 1.
global mosWorkOffsetCodes={"G54","G55","G56","G57","G58","G59","G59.1","G59.2","G59.3"}

global mosProbeRoughSpeed=150    ; Speed used for initial probe movement

global mosProbeSpeed=25          ; Speed used for subsequent probe movements to increase accuracy

global mosProbeBackoffDistance=2 ; NOTE: You cannot probe any negative features (bores, pockets etc)
                                ; with a length in any axis less than this value, as the probe or tool will collide
                                ; with the opposite face when backing off. Most cheap touch-probes have a tip
                                ; radius of 1mm, so this value should be at least 2mm. Override this if you
                                ; have a smaller probe tip (or tool, for manual probing) and you want to be able
                                ; to probe very small features.

; Coordinates returned by the most recent probing operation.
; Depending on the op, not all of these will be set.
global mosProbeCoordinateX=0
global mosProbeCoordinateY=0
global mosProbeCoordinateZ=0

; Daemon settings
; Required for regular task updates (e.g. VSSC)
global mosDaemonEnable=true

global mosDaemonUpdateRate=500  ; Re-trigger background tasks every 500ms
                                ; don't reduce this below 500!

; Variable Spindle Speed Control settings
global mosVsscDebug=false ; Whether to emit debug information

; Do not change these variables directly, use the VSSC control M-codes instead
global mosVsscEnabled=false
global mosVsscOverrideEnabled=true
global mosVsscPeriod=0
global mosVsscVariance=0.0
global mosVsscSpeedWarningIssued=false
global mosVsscPreviousAdjustmentTime=0
global mosVsscPreviousAdjustmentRPM=0.0

; Define constants for axis indices and names
global mosIX                = 0
global mosIY                = 1
global mosIZ                = 2
global mosNX                = "X"
global mosNY                = "Y"
global mosNZ                = "Z"

; Define constants for probe types
global mosReferenceSurfaceCoords=null
global mosToolSetterCoords=null
global mosToolSetterHeight=null
global mosToolSetterID=null
global mosTouchProbeID=null
global mosSpindleID=null

