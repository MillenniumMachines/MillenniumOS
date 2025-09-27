; nxt-boot.g
; Performs critical sanity checks before allowing NeXT to load.

; 1. Confirm RRF is in CNC mode.
if { state.machineMode != "CNC" }
    set global.nxtError = "Machine mode must be CNC (M453)"
    M99

; 2. Confirm Z-axis is configured correctly (max=0, min=negative)
if { move.axes[2].max > 0 || move.axes[2].min >= 0 }
    set global.nxtError = "Z-axis must have max=0 and min<=0"
    M99

; 3. Check for critical user-defined variables (which will come from the UI config)
if { !exists(global.nxtDeltaMachine) }
    set global.nxtError = "Static datum (nxtDeltaMachine) is not defined. Please run the configuration."
    M99

if { !exists(global.nxtProbeToolID) }
    set global.nxtError = "Probe Tool ID (nxtProbeToolID) is not defined. Please run the configuration."
    M99

; --- All checks passed ---
set global.nxtLoaded = true
