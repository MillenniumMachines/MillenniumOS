; M7500.g: PRINT ALL VARIABLES
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
echo { "  global.mosFeatureVSSC=" ^ global.mosFeatureVSSC }
echo { "===" }

echo { "MOS Probing: " }
echo { "  global.mosReferenceSurfaceZ=" ^ global.mosReferenceSurfaceZ }
echo { "  global.mosProbeCoordinate={" ^ global.mosProbeCoordinate ^ "}" }
echo { "  global.mosOutsideCornerNumber=" ^ global.mosOutsideCornerNum }
echo { "  global.mosOutsideCornerPos={" ^ global.mosOutsideCornerPos ^ "}" }
echo { "  global.mosInsideCornerNumber=" ^ global.mosInsideCornerNum }
echo { "  global.mosInsideCornerPos={" ^ global.mosInsideCornerPos ^ "}" }
