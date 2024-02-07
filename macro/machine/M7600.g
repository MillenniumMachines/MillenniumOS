; M7600.g: PRINT ALL VARIABLES
;
; Outputs all MillenniumOS variables to the console.
; These variables can be useful where you are trying to do
; something non-standard with the probing macros.
; For example: we store the co-ordinates of the last probed
; corner for inside and outside probing macros including
; the index of the corner that was probed. You can
; use these variables in your own macro calls to implement custom
; functionality.

echo { "MOS Features:" }
echo { "  global.mosFeatureToolSetter=" ^ global.mosFeatureToolSetter }
echo { "  global.mosFeatureTouchProbe=" ^ global.mosFeatureTouchProbe }
echo { "  global.mosFeatureSpindleFeedback=" ^ global.mosFeatureSpindleFeedback }
echo { "  global.mosFeatureVSSC=" ^ global.mosFeatureVSSC }
echo { "===" }

echo { "MOS Probing:" }
echo { "  global.mosProbeToolID=" ^ global.mosProbeToolID }
echo { "  global.mosProbeDetected=" ^ global.mosProbeDetected }
echo { "  global.mosDetectedProbeID=" ^ global.mosDetectedProbeID }
echo { "  global.mosProbeCoordinate=" ^ global.mosProbeCoordinate }
echo { "  global.mosProbeVariance=" ^ global.mosProbeVariance }
echo { "  global.mosProbeOvertravel=" ^ global.mosProbeOvertravel }
echo { "  global.mosProbePositionDelay=" ^ global.mosProbePositionDelay }
echo { "  global.mosLastProbeCycle=" ^ global.mosLastProbeCycle }
echo { "  global.mosWorkPieceCenterPos=" ^ global.mosWorkPieceCenterPos }
echo { "  global.mosWorkPieceDimensions=" ^ global.mosWorkPieceDimensions }
echo { "  global.mosWorkPieceRadius=" ^ global.mosWorkPieceRadius }
echo { "  global.mosWorkPieceRotationAngle=" ^ global.mosWorkPieceRotationAngle }
echo { "  global.mosWorkPieceBoundingBox=" ^ global.mosWorkPieceBoundingBox }
echo { "  global.mosWorkPieceCornerNum=" ^ global.mosWorkPieceCornerNum }
echo { "  global.mosWorkPieceCornerPos=" ^ global.mosWorkPieceCornerPos }
echo { "  global.mosWorkPieceCornerAngle=" ^ global.mosWorkPieceCornerAngle }
echo { "  global.mosWorkPieceSurfaceAxis=" ^ global.mosWorkPieceSurfaceAxis }
echo { "  global.mosWorkPieceSurfacePos=" ^ global.mosWorkPieceSurfacePos }
echo { "===" }

echo { "MOS Touch Probe:" }
echo { "  global.mosTouchProbeID=" ^ global.mosTouchProbeID }
echo { "  global.mosTouchProbeRadius=" ^ global.mosTouchProbeRadius }
echo { "  global.mosTouchProbeDeflection=" ^ global.mosTouchProbeDeflection }
echo { "  global.mosTouchProbeReferencePos=" ^ global.mosTouchProbeReferencePos }
echo { "===" }

echo { "MOS Toolsetter:" }
echo { "  global.mosToolSetterID=" ^ global.mosToolSetterID }
echo { "  global.mosToolSetterPos=" ^ global.mosToolSetterPos }
echo { "  global.mosToolSetterActivationPos=" ^ global.mosToolSetterActivationPos }

echo { "MOS Spindle:"}
echo { "  global.mosSpindleID=" ^ global.mosSpindleID }
echo { "  global.mosSpindleAccelSeconds=" ^ global.mosSpindleAccelSeconds }
echo { "  global.mosSpindleDecelSeconds=" ^ global.mosSpindleDecelSeconds }