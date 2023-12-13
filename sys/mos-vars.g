; mos-vars.g
;
; Defines internal variables that we can make safe assumptions about.

; Define global variables that are intended to be overridden by the user in mos-user-vars.g
global featureToolSetter=false
global featureTouchProbe=false
global featureVSSC=true

; Define variables that are used internally by MOS macros.
; These can be overridden in mos-user-vars.g if necessary (but almost certainly do not need to be).

; Define names for corner identities. The corner ID is the index into these arrays, plus 1.
global originCorners={"Front Left","Front Right","Rear Right","Rear Left"}
global originAll={"Front Left","Front Right","Rear Right","Rear Left","Centre"}

; Define names for work offsets. The work offset ID is the index into these arrays, plus 1.
global workOffsetCodes={"G54","G55","G56","G57","G58","G59","G59.1","G59.2","G59.3"}

; Define probing movement speeds in mm/min
global probeRoughSpeed=150 ; Speed used for initial probe movement
global probeSpeed=25       ; Speed used for subsequent probe movements to increase accuracy

; Coordinates returned by the most recent probing operation.
; Depending on the op, not all of these will be set.
global probeCoordinateX=0
global probeCoordinateY=0
global probeCoordinateZ=0

; Probed height of the reference surface. This gives us a reference point for calculating
; tool offsets in relation to the work piece.
global referenceCoordinateZ=0

; Used in conjunction with referenceSurfaceZ, it indicates where (in positive Z co-ordinates)
; from the reference surface the toolsetter switch should be activated.
; The difference in height from this co-ordinate to the _actual_ co-ordinate at which the
; switch is activated is the tool offset.
global expectedToolCoordinateZ=0

; Toolsetter settings
global toolSetterBackoffDistZ=5 ; The distance to back-off in Z before attempting each subsequent tool probe.
global toolSetterNumProbes=5    ; Default number of probes to perform when setting a tool.
global toolSetterRadius=4       ; Radius of toolsetter sexbolt, in mm. Radius offset probing will be performed
                                ; if changing to a tool with a radius larger than this.

; Touch probe settings
global touchProbeNumProbes=5    ; Default number of probes to perform when indicating a surface.
global touchProbeRadius=1       ; Radius of the touch probe tip, in mm.
global touchProbeDeflection=0   ; Amount of deflection of the touch probe tip, in mm, before probe is activated.
                                ; This can be measured by probing the edges of a 1-2-3 block or similar
                                ; in a single axis (e.g. X). The difference between the two probe co-ordinates is the
                                ; probed dimension (in mm) of the block. Subtracting the known dimension of the block
                                ; from the probed dimension gives 2 x the deflection of the probe tip.
                                ; ((X2 - X1) - <measured-x>) / 2 = deflection in mm

global touchProbeBackoffDistZ=2  ; The distance to back-off in Z before attempting each subsequent probe.
global touchProbeBackoffDistXY=5 ; The distance to back-off in X and Y before attempting each subsequent probe.

; Daemon settings
; Required for regular task updates (e.g. VSSC)
global daemonEnable=true     ; Run background tasks in daemon.g
global daemonUpdateRate=500  ; Re-trigger background tasks every 500ms
                             ; don't reduce this below 500!

; Variable Spindle Speed Control settings
global vsscDebug=false ; Whether to emit debug information

; Do not change these variables directly, use the VSSC control M-codes instead
global vsscEnabled=false
global vsscPeriod=0
global vsscVariance=0
global vsscSpeedWarningIssued=false
global vsscPreviousAdjustmentTime=0
global vsscPreviousAdjustmentRPM=0.0
global vsscPreviousAdjustmentDir=true


; Undefined variables:
; These are used internally by MOS macros, but *must* be defined by the user in mos-user-vars.g
; as we cannot choose safe defaults for every machine.
; We sanity-check that these variables are defined in mos-boot.g
;
; global toolSetterCoords       - X and Y machine coordinates of the center of the toolsetter sexbolt surface.
; global toolSetterHeight       - Measured height from the reference surface to the toolsetter sexbolt
;                                 surface, at the point when the toolsetter switch is activated.
; global referenceSurfaceCoords - X and Y machine coordinates of the center of the reference surface.