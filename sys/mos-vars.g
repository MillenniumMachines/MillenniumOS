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

; Coordinates returned by the most recent probing operation.
global mosProbeCoordinate={ null, null, null }
global mosProbeVariance={ null, null, null }

global mosProbeOvertravel=2.0 ; Overtravel distance in mm

global mosBoreRadius=null
global mosBoreCenterPos={null, null}

; These are the X and Y coordinates of the center
; of the most recent rectangular pocket probe.
global mosRectanglePocketCenterPos={null, null}
global mosRectanglePocketDimensions={null, null}

; These are the X and Y coordinates of the center
; of the most recent rectangle block probe.
global mosRectangleBlockCenterPos={null, null}

; These are the calculated dimensions, in mm, of the
; most recent rectangle block probe.
global mosRectangleBlockDimensions={null, null}

; When probing an outside corner, move inwards by
; this distance in mm for the initial probe.
global mosOutsideCornerDefaultDistance=10.0

; This is the corner number that was picked by the
; operator for the most recent outside corner probe
global mosOutsideCornerNum=null

; These are the X and Y coordinates of the most recent
; outside corner probe.
global mosOutsideCornerPos={null, null}

; This is the corner number that was picked by the
; operator for the most recent inside corner probe
global mosInsideCornerNum=null

; These are the X and Y coordinates of the most recent
; inside corner probe.
global mosInsideCornerPos={null, null}

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
global mosN                 = {"X","Y","Z"}


; Define constants for probe types
global mosReferenceSurfaceCoords=null
global mosReferenceSurfaceZ=null
global mosToolSetterCoords=null
global mosToolSetterHeight=null
global mosToolSetterID=null
global mosTouchProbeID=null
global mosSpindleID=null

