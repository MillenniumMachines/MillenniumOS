; mos-boot.g
;
; Load MillenniumOS.
; This involves sanity checking variables and aborting if they are not set.

; Confirm RRF is in CNC mode.
if { state.machineMode != "CNC" }
    set global.mosErr = { "Machine mode must be set to CNC using M453!" }
    M99

if { move.axes[2].max > 0 || move.axes[2].min >= 0 }
    set global.mosErr = { "Your Z axis uses positive co-ordinates which are untested and unsupported. Please configure your Z max as 0 and Z min as a negative number." }
    M99

; Remove existing probe tool so
; it can be redefined.
M4001 P{global.mosPTID}

; If we have a touch probe, make sure the relevant variables are set
if { global.mosFeatTouchProbe }
    ; If we have a touch probe, make sure we have the ID set
    if { !exists(global.mosTPID) || global.mosTPID == null }
        set global.mosErr = { "<b>global.mosTPID</b> must contain the ID of the touch probe. Configure it using M558 K<probe-id>... in config.g, then run the configuration wizard (<b>G8000</b>)." }
        M99
    if { !exists(global.mosTPRP) || global.mosTPRP == null }
        set global.mosErr = { "<b>global.mosTPRP</b> is not set." }
        M99
    if { !exists(global.mosTPR) || global.mosTPR == null }
        set global.mosErr = { "<b>global.mosTPR</b> is not set." }
        M99
    if { !exists(global.mosTPD) || global.mosTPD == null }
        set global.mosErr = { "<b>global.mosTPD</b> is not set." }
        M99

    ; Add a touch probe tool at the last index in the tool table.
    ; Make sure to specify deflection values for compensation.
    M4000 S{"Touch Probe"} P{global.mosPTID} R{global.mosTPR} X{global.mosTPD[0]} Y{global.mosTPD[1]} I{-1}
else
    if { !exists(global.mosDTR) || global.mosDTR == null }
        set global.mosErr = { "<b>global.mosDTR</b> is not set." }
        M99

    ; Add a datum tool at the last index in the tool table.
    M4000 S{"Datum Tool"} P{global.mosPTID} R{global.mosDTR} I{-1}

; If we have a toolsetter, make sure the relevant variables are set
if { global.mosFeatToolSetter }
    if { !exists(global.mosTSID) || global.mosTSID == null }
        set global.mosErr = { "<b>global.mosTSID</b> must contain the ID of the Toolsetter probe. Configure it using M558 K[probe-id]... in config.g, then run the configuration wizard (<b>G8000</b>)." }
        M99
    if { !exists(global.mosTSP) || global.mosTSP == null }
        set global.mosErr = { "<b>global.mosTSP</b> is not set." }
        M99
    if { !exists(global.mosTSR) || global.mosTSR == null }
        set global.mosErr = { "<b>global.mosTSR</b> is not set." }
        M99


; Make sure protected move back-off is set with touchprobe or toolsetter enabled
if { (global.mosFeatToolSetter || global.mosFeatTouchProbe) && global.mosPMBO == null }
    set global.mosErr = { "<b>global.mosPMBO</b> is not set." }
    M99

if { !exists(global.mosSAS) || global.mosSAS == null }
    set global.mosErr = { "<b>global.mosSAS</b> is not set." }
    M99

if { !exists(global.mosSDS) || global.mosSDS == null }
    set global.mosErr = { "<b>global.mosSDS</b> is not set." }
    M99

; Allow MOS macros to run.
set global.mosLdd = true

if { global.mosEM }
    echo { "WARNING: Expert mode is enabled! You will not be asked to confirm any actions. Be careful!" }
