# MillenniumOS Custom G and M Codes Documentation

This document outlines the custom G and M codes implemented in MillenniumOS, detailing their functionality, arguments, and operational specifics.

---

## MillenniumOS Core System Macros

### mos.g (MillenniumOS Entrypoint)

*   **Code:** (Internal macro, typically called from `config.g`)
*   **Description:** `mos.g` is the primary entry point for initializing MillenniumOS, intended to be included at the end of RRF's `config.g` file using `M98 P"mos.g"`. It handles version management, loads configuration, manages the daemon, and performs initial setup checks.
*   **Arguments:** None.
*   **How it works:**
    *   **Version Management:** Sets or updates the `global.mosVer` variable with the current MillenniumOS release version.
    *   **Variable Initialization:** Loads internal/default variables from `mos-vars.g` if `global.mosVarsLoaded` is not set. Initializes `global.mosLdd` (MillenniumOS Loaded) and `global.mosErr` (MillenniumOS Error).
    *   **Configuration Wizard Trigger:** If `0:/sys/mos-user-vars.g` (user configuration file) does not exist, it echoes a message and automatically runs `G8000` (Configuration Wizard), then aborts (`M99`).
    *   **Cleanup:** Deletes `mos-user-vars.g.example` if it exists.
    *   **Daemon Installation:** If `0:/sys/daemon.install` exists, it backs up any existing `daemon.g` to `daemon.g.old` and then renames `daemon.install` to `daemon.g`. This ensures the latest `daemon.g` is active.
    *   **Load User/Override Vars:** Loads user-specific variables from `mos-user-vars.g` and `mos-override-vars.g` if they exist.
    *   **Sanity Checks and Final Boot:** Calls `M98 P"mos-boot.g"` to perform final sanity checks and complete the boot process.
*   **Inclusion:** Should be called once from `config.g` using `M98 P"mos.g"`.

### mos-boot.g (MillenniumOS Boot Sanity Checks)

*   **Code:** (Internal macro, called by `mos.g`)
*   **Description:** This macro performs critical sanity checks on the RepRapFirmware environment and the MillenniumOS configuration variables during the boot sequence. Its primary role is to ensure that the machine is configured correctly for MillenniumOS to function safely and as expected. If any critical checks fail, it sets an error flag and aborts the MillenniumOS loading process.
*   **Arguments:** None.
*   **How it works:**
    *   **CNC Mode Check:** Verifies that the machine is operating in "CNC" mode (`state.machineMode`). If not, it sets `global.mosErr` and aborts, as MillenniumOS is designed for CNC operations.
    *   **Z-Axis Configuration Check:** Aborts if the Z-axis is configured with positive coordinates (expects Z max as 0 and Z min as a negative number).
    *   **Probe Tool Initialization:** Removes any existing probe tool (`M4001 P{global.mosPTID}`) to ensure a clean slate for its redefinition.
    *   **Touch Probe Validation:** If `global.mosFeatTouchProbe` is enabled, it checks for the existence and validity of `global.mosTPID`, `global.mosTPRP`, `global.mosTPR`, and `global.mosTPD`. If any are missing, it sets `global.mosErr` and aborts. It then defines the "Touch Probe" tool using `M4000`.
    *   **Datum Tool Validation:** If `global.mosFeatTouchProbe` is *not* enabled, it checks for `global.mosDTR` (Datum Tool Radius) and defines the "Datum Tool" using `M4000`.
    *   **Toolsetter Validation:** If `global.mosFeatToolSetter` is enabled, it checks for `global.mosTSID`, `global.mosTSP`, and `global.mosTSR`. If any are missing, it sets `global.mosErr` and aborts.
    *   **Protected Move Back-Off Check:** Ensures `global.mosPMBO` is set if either toolsetter or touch probe features are enabled.
    *   **Spindle Acceleration/Deceleration Check:** Ensures `global.mosSAS` and `global.mosSDS` are set.
    *   **Final Load Confirmation:** Sets `global.mosLdd = true` if all checks pass, indicating MillenniumOS is successfully loaded.
    *   **ATX Power Activation:** Calls `M80.9` to conditionally prompt the operator to enable ATX power if configured.
    *   **Restore Settings:** Calls `M501.1` to load any previously saved WCS details and tool offsets from a restore point.
    *   **Expert Mode Warning:** If `global.mosEM` (Expert Mode) is enabled, it echoes a warning to the console about the reduced safety prompts.
*   **Inclusion:** Called by `mos.g` during the MillenniumOS boot process.

### daemon.g (MillenniumOS Daemon Framework)

*   **Code:** (Internal macro, executed by RRF's daemon system)
*   **Description:** `daemon.g` serves as the central framework for running scheduled background tasks within MillenniumOS. It operates in a continuous loop, executing various system and user-defined daemon macros at regular intervals.
*   **Arguments:** None.
*   **How it works:**
    *   **Startup Messages:** Immediately calls `M98 P"mos/display-startup-messages.g"` to ensure any pending startup messages are shown to the operator.
    *   **Loop Control:** Enters a `while` loop that continues as long as `global.mosDAE` (MillenniumOS Daemon Enabled) is `true`.
    *   **Interval:** Inside the loop, it pauses for `global.mosDAEUR` (Daemon Update Rate) milliseconds using `G4 P{global.mosDAEUR}`, defining the minimum interval between daemon runs.
    *   **ArborCtl Integration:** Checks for the existence of `0:/sys/arborctl/arborctl-daemon.g` and executes it if found, allowing integration with the ArborCtl system.
    *   **VSSC Integration:** If Variable Spindle Speed Control (VSSC) is enabled (`global.mosFeatVSSC`, `global.mosVSEnabled`, and `global.mosVSOE` are all `true`), it executes `M98 P"mos/run-vssc.g"` to manage spindle speed variations.
    *   **User-Defined Daemon:** Checks for the existence of `0:/sys/user-daemon.g` and executes it if found, providing a hook for users to add their own custom background tasks without modifying core MillenniumOS files.
*   **Inclusion:** This macro is typically installed and managed by `mos.g` during the MillenniumOS boot process.

---

## Machine Control Macros (`macro/machine/`)

### M3.9: SPINDLE ON, CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE

*   **Code:** `M3.9`
*   **Description:** Turns the spindle on in a clockwise direction and waits for it to accelerate to the target speed. This macro ensures the spindle is ready before proceeding with operations, taking into account VFD setup and spindle power.
*   **Arguments:**
    *   `S<rpm>`: (Optional) Target spindle speed in RPM.
    *   `P<spindle-id>`: (Optional) The ID of the spindle to control. Defaults to `global.mosSID`.
    *   `D<override-dwell-seconds>`: (Optional) Overrides the calculated dwell time for acceleration with a specified duration in seconds.
*   **How it works:**
    *   Validates `P`, `S`, and `D` parameters, ensuring positive values and valid spindle ID/speed ranges.
    *   Executes `M400` to wait for all movement to stop.
    *   If not in expert mode (`global.mosEM`), displays a caution message to the operator.
    *   Calculates the required dwell time based on `global.mosSAS` (spindle acceleration time) or `global.mosSDS` (spindle deceleration time if changing speed), or uses the `D` parameter if provided.
    *   Activates the spindle using the standard `M3` command with the specified speed and ID.
    *   If `global.mosFeatSpindleFeedback` is enabled, it waits for spindle feedback using `M8004`. Otherwise, it uses `G4` for a dwell based on the calculated `dwellTime`.

### M3000: EMIT CONFIRMATION DIALOG

*   **Code:** `M3000`
*   **Description:** Displays a confirmation dialog to the operator with "Continue", "Pause", and "Cancel" options. The "Pause" option is only available if a job is currently running. Selecting "Cancel" will abort the current job.
*   **Arguments:**
    *   `S<message>`: The main message content to display in the dialog.
    *   `R<title>`: The title of the dialog box.
*   **How it works:**
    *   Validates that both `S` (message) and `R` (title) parameters are provided.
    *   Prevents the dialog from being displayed if the machine is in a "resuming", "pausing", or "paused" state.
    *   If a job file is active (`job.file.fileName != null`), it presents options for "Continue", "Pause", and "Cancel" using `M291`.
    *   If no job is active, it presents "Continue" and "Cancel" options.
    *   If the operator selects "Cancel" (input > 0 or input > 1 depending on options), the job is aborted.
    *   If the operator selects "Pause" (input != 0 when pause is an option), `M25` is called to pause the job.

### M4.9: SPINDLE ON, COUNTER-CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE

*   **Code:** `M4.9`
*   **Description:** Turns the spindle on in a counter-clockwise direction and waits for it to accelerate to the target speed. This macro is similar to `M3.9` but for reverse rotation.
*   **Arguments:**
    *   `S<rpm>`: (Optional) Target spindle speed in RPM.
    *   `P<spindle-id>`: (Optional) The ID of the spindle to control. Defaults to `global.mosSID`.
    *   `D<override-dwell-seconds>`: (Optional) Overrides the calculated dwell time for acceleration with a specified duration in seconds.
*   **How it works:**
    *   Validates `P`, `S`, and `D` parameters, ensuring positive values and valid spindle ID/speed ranges.
    *   Checks if the selected spindle (`var.sID`) is configured to allow counter-clockwise rotation (`spindles[var.sID].canReverse`). Aborts if not.
    *   Executes `M400` to wait for all movement to stop.
    *   If not in expert mode (`global.mosEM`), displays a caution message to the operator.
    *   Calculates the required dwell time similar to `M3.9`.
    *   Activates the spindle using the standard `M4` command with the specified speed and ID.
    *   If `global.mosFeatSpindleFeedback` is enabled, it waits for spindle feedback using `M8004`. Otherwise, it uses `G4` for a dwell based on the calculated `dwellTime`.

### M4000: DEFINE TOOL

*   **Code:** `M4000`
*   **Description:** Defines a tool by its index. This macro creates an RRF tool and links it to a managed spindle, storing additional tool information such as radius and deflection values for MillenniumOS's internal use.
*   **Arguments:**
    *   `P<tool-number>`: The 0-indexed number of the tool to define.
    *   `R<radius>`: The radius of the tool in millimeters.
    *   `S<description>`: A descriptive name or label for the tool.
    *   `I<spindle-id>`: (Optional) Overrides the default spindle ID (`global.mosSID`) to associate the tool with a specific spindle.
    *   `X<deflection-x>`: (Optional) The deflection distance of the tool in the X-axis, typically used for probing tools.
    *   `Y<deflection-y>`: (Optional) The deflection distance of the tool in the Y-axis, typically used for probing tools.
*   **How it works:**
    *   Validates `P`, `R`, and `S` parameters, ensuring `P` is within `limits.tools` and `S` has a minimum length.
    *   Performs a check to see if a tool with the same parameters (radius, spindle, name, deflection) is already defined. If so, it exits without re-defining to allow re-running of tool definition files.
    *   Defines the RRF tool using `M563` with the specified tool number, name, and associated spindle ID.
    *   Stores the tool's radius in `global.mosTT[P][0]`.
    *   If `X` and `Y` parameters are provided, their values are stored as deflection distances in `global.mosTT[P][1][0]` and `global.mosTT[P][1][1]` respectively.

### M4001: REMOVE TOOL

*   **Code:** `M4001`
*   **Description:** Removes a tool by its index, resetting its definition in RRF and clearing its associated data in MillenniumOS.
*   **Arguments:**
    *   `P<tool-number>`: The 0-indexed number of the tool to remove.
*   **How it works:**
    *   Validates the `P` parameter, ensuring it's within `limits.tools`.
    *   Checks if the tool actually exists in the RRF tool array. If not, it exits.
    *   Resets the RRF tool definition using `M563` with `R-1` (unassigned spindle) and a default name "Unknown Tool".
    *   Resets the corresponding entry in `global.mosTT` to `global.mosET` (empty tool) to clear MillenniumOS's internal tool details.

### M4005: CHECK MILLENNIUMOS POST VERSION

*   **Code:** `M4005`
*   **Description:** Verifies that the version of the post-processor being used matches the installed version of MillenniumOS. This ensures compatibility between the generated G-code and the firmware's capabilities.
*   **Arguments:**
    *   `V<version>`: The version string of the post-processor.
*   **How it works:**
    *   Validates that the `V` parameter is provided.
    *   Compares the provided `param.V` with the `global.mosVer` variable, which holds the installed MillenniumOS version.
    *   If the versions do not match, it aborts the execution with an error message indicating the mismatch.

### M5.9: SPINDLE OFF

*   **Code:** `M5.9`
*   **Description:** Turns the spindle off and waits for it to decelerate. This macro ensures the spindle has come to a complete stop before further operations, accounting for VFD setup and deceleration characteristics.
*   **Arguments:**
    *   `D<override-dwell-seconds>`: (Optional) Overrides the calculated dwell time for deceleration with a specified duration in seconds.
*   **How it works:**
    *   Validates the `D` parameter, ensuring a positive value.
    *   Executes `M400` to wait for all movement to stop.
    *   Determines if any spindle is currently running. If so, it identifies the spindle and calculates the required dwell time based on `global.mosSDS` (spindle deceleration time) or the `D` parameter if provided.
    *   Executes the standard `M5` command to stop the spindle.
    *   If `global.mosFeatSpindleFeedback` is enabled, it waits for spindle feedback using `M8004`. Otherwise, it uses `G4` for a dwell based on the calculated `dwellTime`.

### M500.1: SAVE RESTORABLE SETTINGS

*   **Code:** `M500.1`
*   **Description:** Saves the current Work Coordinate System (WCS) origins, the toolsetter activation point (if configured), and all defined tool details to a file named `mos-restore-point.g`. This file can be loaded later to restore the machine's state.
*   **Arguments:** None.
*   **How it works:**
    *   Creates or overwrites the file `0:/sys/mos-restore-point.g`.
    *   Writes comments to the file indicating its purpose and that it's auto-generated.
    *   **WCS Origins:** Iterates through all available workplaces (`limits.workplaces`) and writes `G10 L2 P<id> X<x> Y<y> Z<z>` commands to restore each WCS origin.
    *   **Touch Probe Activation Point:** If `global.mosFeatTouchProbe` is enabled and `global.mosTSAP` (toolsetter activation point) is set, it saves this value.
    *   **Tools:** Iterates through all defined tools (excluding the probe tool) and writes `M4000` commands to redefine them with their stored radius and name.
    *   **Current Tool and Offset:** If a tool is currently selected (`state.currentTool != -1`), it writes commands to select that tool (`T<id> P0`) and set its Z offset (`G10 L1 P<id> Z<z>`).
    *   **Current WCS:** Writes the G-code command for the currently active WCS (e.g., `G54`, `G55`).
    *   Echoes a confirmation message that the restore point has been saved.

### M5000: RETURN MACHINE INFORMATION

*   **Code:** `M5000`
*   **Description:** Retrieves and returns current machine position information, specifically absolute coordinates.
*   **Arguments:**
    *   `P<mode>`: Specifies the type of machine information to return.
        *   `P0`: Returns the current absolute coordinates for all axes (X, Y, Z).
        *   `P1`: Returns the current absolute coordinate for a single axis.
    *   `I<axis-id>`: (Required with `P1`) The 0-indexed ID of the axis to query (0 for X, 1 for Y, 2 for Z).
*   **How it works:**
    *   Validates the `P` parameter and, if `P1` is used, the `I` parameter.
    *   Ensures `global.mosMI` (MillenniumOS Machine Information) is initialized.
    *   Executes `M400` to wait for all movement to stop, ensuring accurate position readings.
    *   If `P0`, it populates `global.mosMI` with a vector containing the current absolute position for each axis, calculated by summing workplace offsets, tool offsets (if a tool is active), and user position.
    *   If `P1`, it populates `global.mosMI` with the current absolute position of the specified axis, using the same calculation.

### M501.1: LOAD RESTORABLE SETTINGS OR DISCARD RESTORE POINT

*   **Code:** `M501.1`
*   **Description:** Loads previously saved machine settings from `mos-restore-point.g` or discards the existing restore point file.
*   **Arguments:**
    *   `D1`: (Optional) If present, the restore point file will be discarded without prompting the operator.
*   **How it works:**
    *   Checks for the existence of `0:/sys/mos-restore-point.g`.
    *   If the file exists and `D1` is not provided, it displays a dialog (`M291`) asking the operator to "Load" or "Discard" the restore point.
    *   If "Load" is selected (or implied by context), it executes the `mos-restore-point.g` file using `M98`, then displays a warning to the operator to carefully check the restored settings.
    *   If "Discard" is selected (or `D1` is provided), it first backs up the `mos-restore-point.g` file to `mos-restore-point.g.bak` using `M471` and then deletes the original. It echoes a message confirming the backup and discard.
    *   If no restore point file is found, it echoes a message indicating this.

### M5010: RESET WCS PROBE DETAILS

*   **Code:** `M5010`
*   **Description:** Resets specific probed details for a Work Coordinate System (WCS). This includes parameters like center position, corner position, radius, surface position, dimensions, and rotation, allowing for a clean slate before new probing operations.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number (e.g., 0 for G54, 1 for G55) for which to reset details. Defaults to the current workplace number.
    *   `R<reset-mask>`: (Optional) A bitmask to specify which details to reset. The bits correspond to:
        *   Bit 0 (1): Center position (`global.mosWPCtrPos`)
        *   Bit 1 (2): Corner position (`global.mosWPCnrPos`, `global.mosWPCnrDeg`, `global.mosWPCnrNum`)
        *   Bit 2 (4): Radius (`global.mosWPRad`)
        *   Bit 3 (8): Surface position (`global.mosWPSfcAxis`, `global.mosWPSfcPos`)
        *   Bit 4 (16): Dimensions (`global.mosWPDims`, `global.mosWPDimsErr`)
        *   Bit 5 (32): Rotation (`global.mosWPDeg`)
        *   Defaults to 63 (resets all listed details).
*   **How it works:**
    *   Validates the `W` parameter, ensuring it's within the valid range of workplaces.
    *   The `R` parameter is interpreted as a bitmask. For each bit set in the mask, the corresponding global variable(s) for the specified `workOffset` are reset to their default/null values.
    *   If `global.mosTM` (tutorial mode) is enabled, it echoes messages indicating which WCS details are being reset.

### M5011: APPLY ROTATION COMPENSATION

*   **Code:** `M5011`
*   **Description:** Applies rotation compensation to the current Work Coordinate System (WCS) if a rotation has been previously probed and stored for that WCS. This helps align machining operations with a rotated workpiece.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number for which to apply rotation compensation. Defaults to the current workplace number.
*   **How it works:**
    *   Validates the `W` parameter, ensuring it's within the valid range of workplaces.
    *   Checks `global.mosWPDeg[var.workOffset]` to determine if a non-default rotation angle has been stored for the specified WCS.
    *   If a rotation exists:
        *   It prompts the user via `M291` to confirm applying the rotation compensation, displaying the detected angle.
        *   If the user confirms, it applies the rotation using the `G68` command, rotating around the origin (X0 Y0) by the stored angle.
        *   It echoes a confirmation message about the applied rotation.
    *   If no rotation exists or the user cancels, it executes `G69` to cancel any existing rotation compensation.

### M5012: RESET PROBE COUNTS

*   **Code:** `M5012`
*   **Description:** Resets all internal counters related to probing operations. This macro is typically called at the completion of a probing sequence to clear the status for subsequent operations.
*   **Arguments:** None.
*   **How it works:**
    *   Sets the following global variables to 0:
        *   `global.mosPRRT`: Probe Retries Total
        *   `global.mosPRRS`: Probe Retries Remaining
        *   `global.mosPRPT`: Probe Points Total
        *   `global.mosPRPS`: Probe Points Success
        *   `global.mosPRST`: Probe Surfaces Total
        *   `global.mosPRSS`: Probe Surfaces Success

### M6515: CHECK MACHINE LIMITS

*   **Code:** `M6515`
*   **Description:** Verifies if a given target position (X, Y, or Z) is within the configured physical limits of the machine. If any coordinate is outside the defined minimum or maximum limits for its axis, the macro will abort execution.
*   **Arguments:**
    *   `X<position>`: (Optional) The X-coordinate to check.
    *   `Y<position>`: (Optional) The Y-coordinate to check.
    *   `Z<position>`: (Optional) The Z-coordinate to check.
*   **How it works:**
    *   Validates that at least one of the `X`, `Y`, or `Z` parameters is provided.
    *   For each provided coordinate, it compares the value against the `move.axes[n].min` and `move.axes[n].max` properties for the corresponding axis (0 for X, 1 for Y, 2 for Z).
    *   If any coordinate is found to be outside its allowed range, it immediately aborts the macro with a descriptive error message indicating which axis limit was violated and the problematic coordinate.

### M7.1: AIR BLAST ON

*   **Code:** `M7.1`
*   **Description:** Activates the air blast output for chip clearing. This macro is part of the coolant control system.
*   **Arguments:** None.
*   **How it works:**
    *   Checks if `global.mosFeatCoolantControl` is enabled and if `global.mosCAID` (Air Coolant ID) is configured. If either is not met, it echoes a message and exits without error.
    *   Executes `M400` to wait for all movement to stop before activating the output.
    *   Turns on the air blast output using `M42 P{global.mosCAID} S1`, where `global.mosCAID` is the configured pin ID for air blast.

### M7: MIST ON

*   **Code:** `M7`
*   **Description:** Activates mist coolant, which typically involves a combination of air and unpressurized coolant flow. This macro first ensures the air blast is on, then activates the mist output.
*   **Arguments:** None.
*   **How it works:**
    *   Checks if `global.mosFeatCoolantControl` is enabled and if `global.mosCMID` (Mist Coolant ID) is configured. If either is not met, it echoes a message and exits without error.
    *   Executes `M400` to wait for all movement to stop.
    *   Calls `M7.1` to ensure the air blast is active.
    *   Turns on the mist coolant output using `M42 P{global.mosCMID} S1`, where `global.mosCMID` is the configured pin ID for mist coolant.

### M7000: ENABLE VSSC

*   **Code:** `M7000`
*   **Description:** Enables and configures the Variable Spindle Speed Control (VSSC) feature. VSSC periodically varies the spindle speed to prevent resonances and improve surface finish.
*   **Arguments:**
    *   `P<period-in-ms>`: The period, in milliseconds, for one complete cycle of spindle speed adjustment.
    *   `V<variance>`: The maximum variance, in RPM, by which the spindle speed will be adjusted above and below the target speed.
*   **How it works:**
    *   Validates that both `P` (period) and `V` (variance) parameters are provided.
    *   Checks that the `P` (period) is not less than `global.mosDAEUR` (daemon update rate) and is a multiple of it.
    *   Sets `global.mosVSP` to `param.P`, `global.mosVSV` to `param.V`, and `global.mosVSEnabled` to `true`.
    *   If `global.mosDebug` is enabled, it echoes the VSSC state, period, and variance to the console.

### M7001: DISABLE VSSC

*   **Code:** `M7001`
*   **Description:** Disables the Variable Spindle Speed Control (VSSC) feature.
*   **Arguments:** None.
*   **How it works:**
    *   Sets `global.mosVSEnabled` to `false`, effectively stopping the VSSC daemon process.
    *   If the spindle is currently active (`spindles[global.mosSID].state == "forward"`), it resets the spindle speed to the last recorded "base" RPM (`global.mosVSPS`) using `M568`. This ensures the spindle returns to a constant speed.
    *   Resets `global.mosVSPT` (VSSC adjustment time) and `global.mosVSPS` (VSSC base speed) to 0.
    *   If `global.mosDebug` is enabled, it echoes the VSSC state and, if applicable, the restored RPM.

### M7500: EMIT DEBUG MESSAGE

*   **Code:** `M7500`
*   **Description:** Emits a debug message to the console. This macro is intended for internal use and will only output messages if MillenniumOS's debug mode is enabled. It does not generate errors or warnings if called incorrectly.
*   **Arguments:**
    *   `S<message>`: The string message to be emitted to the console.
*   **How it works:**
    *   Checks if `global.mosDebug` is `true`.
    *   If debug mode is enabled and the `S` parameter exists, it echoes the provided message to the console, prefixed with `[DEBUG]:`. If `S` is missing, it exits silently.

### M7600: PRINT ALL VARIABLES

*   **Code:** `M7600`
*   **Description:** Outputs the current values of all MillenniumOS global variables to the console. This is useful for debugging and understanding the system's configuration and state, especially when working with probing macros.
*   **Arguments:**
    *   `D1`: (Optional) If present, this parameter will also output additional RRF object model information (e.g., `limits`, `move`, `sensors`, `spindles`, `state`, `tools`) for more in-depth debugging.
*   **How it works:**
    *   Echoes various `global.mos` variables, categorized into "MOS Info", "MOS Features", "MOS Probing", "MOS Touch Probe", "MOS Toolsetter", and "MOS Misc".
    *   If `D1` is provided, it uses `M409 K"<object>"` commands to dump the specified RRF object model data to the console.

### M7601: PRINT WORKPLACE DETAILS

*   **Code:** `M7601`
*   **Description:** Outputs non-null details about a specified Work Coordinate System (WCS). The output format varies based on whether expert mode is enabled: human-readable in normal mode, and raw variable names/values in expert mode.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number for which to print details. Defaults to the current workplace number.
*   **How it works:**
    *   Validates the `W` parameter, ensuring it's within the valid range of workplaces.
    *   Determines the 1-indexed `wcsNumber` from the `workOffset`.
    *   If `global.mosEM` (expert mode) is `false`:
        *   It checks various `global.mos` variables related to WCS probing (e.g., `global.mosWPCtrPos`, `global.mosWPRad`, `global.mosWPCnrNum`, `global.mosWPCnrPos`, `global.mosWPCnrDeg`, `global.mosWPDims`, `global.mosWPDimsErr`, `global.mosWPSfcAxis`, `global.mosWPSfcPos`).
        *   For each non-null detail, it echoes a human-readable description and its value to the console.
    *   If `global.mosEM` is `true`:
        *   It echoes the raw variable names and their corresponding values for all relevant `global.mos` WCS variables.

### M8: FLOOD ON

*   **Code:** `M8`
*   **Description:** Activates the flood coolant output, providing pressurized coolant flow over the cutting tool. This macro is part of the coolant control system.
*   **Arguments:** None.
*   **How it works:**
    *   Checks if `global.mosFeatCoolantControl` is enabled and if `global.mosCFID` (Flood Coolant ID) is configured. If either is not met, it echoes a message and exits without error.
    *   Executes `M400` to wait for all movement to stop before activating the output.
    *   Turns on the flood coolant output using `M42 P{global.mosCFID} S1`, where `global.mosCFID` is the configured pin ID for flood coolant.

### M80.9: ENABLE ATX POWER (OPERATOR PROMPT)

*   **Code:** `M80.9`
*   **Description:** Prompts the operator to enable ATX power if it is currently deactivated and an ATX power port is configured. This acts as a safety measure, requiring user confirmation before powering the machine.
*   **Arguments:** None.
*   **How it works:**
    *   Checks if `state.atxPowerPort` is configured. If not, the macro exits silently.
    *   If ATX power (`state.atxPower`) is currently `false` (deactivated), it displays a warning dialog (`M291`) to the operator. The dialog offers "Activate" and "Cancel" options.
    *   If the operator selects "Activate" (input == 0), it executes the standard `M80` command to enable ATX power.
    *   It then echoes a confirmation message to the console.

### M8001: DETECT PROBE BY STATUS CHANGE

*   **Code:** `M8001`
*   **Description:** This macro is used by the MillenniumOS configuration wizard to detect a change in the status of any configured probe. It helps determine which physical probe the user intends to assign as a touch probe or toolsetter.
*   **Arguments:**
    *   `D<delay-ms>`: (Optional) The delay in milliseconds between successive checks of probe status. Defaults to 100ms.
    *   `W<max-wait-s>`: (Optional) The maximum time, in seconds, to wait for a probe status change before aborting. Defaults to 30s.
*   **How it works:**
    *   Resets `global.mosDPID` (MillenniumOS Detected Probe ID) to `null`.
    *   Initializes a vector `previousValues` to store the initial state of all configured probes.
    *   Enters a loop that continues for a maximum of `maxWait` seconds, checking probe status every `delay` milliseconds.
    *   Inside the loop, it iterates through all configured probes (`sensors.probes`).
    *   If a probe's `value[0]` changes from its `previousValues` entry (and `previousValues` was not null), it means a status change has been detected. `global.mosDPID` is then set to the ID of that probe, and the loop breaks.

### M8002: WAIT FOR PROBE STATUS CHANGE BY ID

*   **Code:** `M8002`
*   **Description:** Waits for a specific probe, identified by its ID, to change its status. This is used to verify that a touch probe is connected and functioning, for example, during a tool change or configuration.
*   **Arguments:**
    *   `K<probe-id>`: The ID of the probe to monitor for a status change.
    *   `D<delay-ms>`: (Optional) The delay in milliseconds between successive checks of the probe's status. Defaults to 100ms.
    *   `W<max-wait-s>`: (Optional) The maximum time, in seconds, to wait for a status change before aborting. Defaults to 30s.
*   **How it works:**
    *   Validates the `K` parameter, ensuring it's a valid probe ID within the range of configured probes and of a compatible type (5 or 8).
    *   Initializes `previousValue` to `null`.
    *   Resets `global.mosPD` (MillenniumOS Probe Detected) to `null`.
    *   Enters a loop that continues for a maximum of `maxWait` seconds, checking the probe's status every `delay` milliseconds.
    *   If the probe's `value[0]` changes from `previousValue` (and `previousValue` was not null), it means a status change has been detected. `global.mosPD` is then set to the `probeId`, and the macro exits successfully.
    *   If the `maxWait` period is exceeded without a status change, the macro aborts with an error message.

### M8003: LIST CHANGED GPIN PINS SINCE LAST CALL

*   **Code:** `M8003`
*   **Description:** Detects and lists which general-purpose input (GPIN) pins have changed their state since the last time this macro was called. This is useful for identifying active inputs, for example, during spindle feedback configuration.
*   **Arguments:** None.
*   **How it works:**
    *   Initializes `global.mosGPD` (MillenniumOS GPIN Detected) and `global.mosGPV` (MillenniumOS GPIN Previous Value) as vectors if they don't exist or their size doesn't match the current number of GPINs.
    *   Iterates through all configured GPINs (`sensors.gpIn`).
    *   For each pin, it compares its current `value` with the `global.mosGPV` stored from the previous call.
    *   If a change is detected (and `global.mosGPV` was not null), the corresponding entry in `global.mosGPD` is set to `true`, and a message is echoed to the console indicating which pin changed state.
    *   Finally, it updates `global.mosGPV` with the current values of all GPINs for the next call.

### M8004: WAIT FOR GPIN STATUS CHANGE BY ID

*   **Code:** `M8004`
*   **Description:** Waits for a specific general-purpose input (GPIN) pin, identified by its ID, to change its status. This is used in scenarios like waiting for spindle feedback or other external events.
*   **Arguments:**
    *   `K<pin-id>`: The ID of the GPIN pin to monitor for a status change.
    *   `D<delay-ms>`: (Optional) The delay in milliseconds between successive checks of the pin's status. Defaults to 100ms.
    *   `W<max-wait-s>`: (Optional) The maximum time, in seconds, to wait for a status change before aborting. Defaults to 30s.
*   **How it works:**
    *   Validates the `K` parameter, ensuring it's a valid pin ID within the range of configured GPINs.
    *   Initializes `previousValue` to `null`.
    *   Enters a loop that continues for a maximum of `maxWait` seconds, checking the pin's status every `delay` milliseconds.
    *   If the pin's `value` changes from `previousValue` (and `previousValue` was not null), it means a status change has been detected, and the macro exits successfully.
    *   If the `maxWait` period is exceeded without a status change, the macro aborts with an error message.

### M81.9: DISABLE ATX POWER (OPERATOR PROMPT)

*   **Code:** `M81.9`
*   **Description:** Prompts the operator to disable ATX power if it is currently activated and an ATX power port is configured. This acts as a safety measure, requiring user confirmation before cutting power to the machine.
*   **Arguments:** None.
*   **How it works:**
    *   Checks if `state.atxPowerPort` is configured. If not, the macro exits silently.
    *   If ATX power (`state.atxPower`) is currently `true` (activated), it displays a warning dialog (`M291`) to the operator. The dialog offers "Deactivate" and "Cancel" options, highlighting the potential impact of disabling power.
    *   If the operator selects "Deactivate" (input == 0), it executes the standard `M81` command to disable ATX power.
    *   It then echoes a confirmation message to the console.

### M9: CONTROL ALL COOLANTS

*   **Code:** `M9`
*   **Description:** By default, this macro disables all configured coolant outputs (flood, mist, and air blast). It can also restore the previous state of coolant outputs if specifically requested, with the state typically saved during a pause operation.
*   **Arguments:**
    *   `R1`: (Optional) If present, this parameter instructs the macro to restore the previous state of the coolant outputs rather than turning them all off.
*   **How it works:**
    *   Checks if `global.mosFeatCoolantControl` is enabled. If not, the macro exits silently.
    *   Executes `M400` to wait for all movement to stop before adjusting coolant outputs.
    *   A `restore` variable is set to `true` if `R1` is present.
    *   For each configured coolant output (air, mist, flood, identified by `global.mosCAID`, `global.mosCMID`, `global.mosCFID` respectively):
        *   If `restore` is `true`, the output is set to its previously saved state (`global.mosPS[pinID]`).
        *   Otherwise, the output is set to `S0` (off).
    *   The `M42` command is used to control the state of the general-purpose output pins.

### M9999: RELOAD MOS

*   **Code:** `M9999`
*   **Description:** Reloads the MillenniumOS core files on the fly without requiring a full mainboard reboot. This is useful for applying changes to macros or configuration without interrupting ongoing operations or requiring a complete system restart.
*   **Arguments:** None.
*   **How it works:**
    *   Echoes a "Reloading..." message to the console.
    *   Resets `global.mosStartupMsgsDisplayed` to `false` to ensure any new startup messages are shown after the reload.
    *   Checks if daemon tasks (`global.mosDAE`) are currently enabled. If so, it temporarily disables them, waits for two daemon update cycles (`G4 P{global.mosDAEUR*2}`) to allow the daemon script to exit gracefully, and then re-enables them after the reload.
    *   Executes `M98 P"mos.g"` to reload the main MillenniumOS configuration file.
    *   Resets the daemon status (`global.mosDAE`) to its previous state.

---

## Movement Control Macros (`macro/movement/`)

### G27: PARK

*   **Code:** `G27`
*   **Description:** Parks the spindle and centers the work area in an accessible location. This is often used as a safe state before tool changes or at the end of a job.
*   **Arguments:**
    *   `Z1`: (Optional) If present, only moves the spindle to the top of its Z travel and stops it, without moving the X or Y axes.
*   **How it works:**
    *   Ensures the macro is not executed by a secondary motion system.
    *   Sets absolute positioning (`G90`), millimeters as units (`G21`), and feed rate mode (`G94`).
    *   Turns off all coolant outputs using `M9`.
    *   If the Z-axis is homed, it moves the spindle to its maximum Z position (`G53 G0 Z{move.axes[2].max}`).
    *   Executes `M400` to wait for all movement to stop.
    *   Stops the spindle using `M5.9`.
    *   If the `Z` parameter is *not* present and both X and Y axes are homed, it moves the table to the center of X and the front of Y (`G53 G0 X... Y...`).
    *   Executes `M400` again to wait for movement to stop.

### G37.1: PROBE Z SURFACE WITH CURRENT TOOL

*   **Code:** `G37.1`
*   **Description:** Performs a single Z-axis surface probe using the currently installed tool. This macro is specifically designed for scenarios where a toolsetter is disabled, requiring manual re-zeroing of the Z origin after each tool change. It is not intended as a generalized probing macro.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[12]`), it displays a series of `M291` dialogs explaining the necessity of setting the Z origin manually and providing guidance.
    *   Prompts the operator to jog the tool above their chosen origin point in Z using `M291` with jogging enabled.
    *   Prompts the operator to enter the `probeDist` (distance to probe towards the surface) and `overtravel` distance using `M291`.
    *   Retrieves the current machine's Z position using `M5000 P1 I2`.
    *   Calculates the target Z position (`tPZ`) by subtracting `probeDist` and `overtravel` from the current Z.
    *   Checks if the calculated `tPZ` is within machine limits using `M6515`.
    *   Initiates a manual probe using `G6512` with the current Z as the start height (`L`) and `tPZ` as the target.
    *   If the probe fails (indicated by `global.mosMI[2]` being null), it aborts.
    *   Parks the spindle in Z (`G27 Z1`).
    *   Sets the Z origin of the current Work Coordinate System (WCS) to the probed Z coordinate using `G10 L2 P{var.wPN} Z{global.mosMI[2]}`.

### G37: TOOL LENGTH PROBE: EXECUTE

*   **Code:** `G37`
*   **Description:** Probes the length of the currently selected tool and saves its offset. This macro intelligently handles different configurations, including the presence of a toolsetter or touch probe, and calculates offsets relative to a datum tool or reference surface.
*   **Arguments:** None.
*   **How it works:**
    *   Aborts if `global.mosFeatToolSetter` is disabled, as tool length probing without a toolsetter is not currently supported.
    *   Aborts if `global.mosFeatTouchProbe` is enabled but the reference surface (`global.mosTSAP`) has not been probed, requiring `G6511` to be run first.
    *   Parks the spindle (`G27 Z1`).
    *   Aborts if the machine is in a paused state.
    *   Aborts if no tool is currently selected.
    *   Resets the Z offset for the current tool to 0 (`G10 P{state.currentTool} Z0`).
    *   **Multi-point Probing (for large tools):** If the current tool's radius (`global.mosTT[state.currentTool][0]`) is greater than `global.mosTSR` (toolsetter radius), it performs a multi-point probe. It first probes the center of the tool, then calculates and probes multiple points around the tool's circumference to find the lowest point, storing these in `pZ`.
    *   **Single-point Probing:** Otherwise, it performs a single probe towards the axis minimum using `G6512` at the toolsetter's X/Y position.
    *   Calculates the `toolOffset`:
        *   If `global.mosFeatTouchProbe` is enabled, the offset is calculated relative to `global.mosTSAP` (toolsetter activation point relative to the reference surface).
        *   If the current tool is the datum tool (`global.mosPTID`), it stores the probed activation point in `global.mosTSAP` but does not apply an offset to the datum tool itself.
        *   If probing a normal cutting tool (and `global.mosTSAP` is set), it calculates the offset relative to the datum tool's activation point.
        *   Aborts if no datum tool activation point is found.
    *   Parks the spindle in Z (`G27 Z1`).
    *   Sets the tool's Z offset using `G10 P{state.currentTool} X0 Y0 Z{var.toolOffset}`.
    *   Saves the updated settings to the restore point file using `M500.1`.

### G6500.1: BORE - EXECUTE

*   **Code:** `G6500.1`
*   **Description:** Probes the inside surface of a circular bore to accurately determine its X and Y center coordinates. It uses multiple probe points around the bore's circumference and geometric calculations to find the center.
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the bore's center.
    *   `K<start-y>`: The approximate Y position of the bore's center.
    *   `L<start-z>`: The Z position (absolute) from which to start probing (below the surface of the bore).
    *   `Z<probe-z>`: The absolute Z position at which the horizontal probing will occur.
    *   `H<bore-diameter>`: The approximate diameter of the bore.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `Z`, `H`) and `W`.
    *   Increments `global.mosPRST` (probe surfaces total) and `global.mosPRPT` (probe points total) for status reporting.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (center, rotation, radius) for the target `workOffset` using `M5010`.
    *   Calculates the effective `overtravel` by subtracting the tool radius and determines the `bR` (bore radius).
    *   Sets `safeZ` to the `L` parameter.
    *   Generates three probe points equally spaced around the bore's circumference. Each point includes a start position (offset by `bR + overtravel`) and a target position (offset by `bR - overtravel`).
    *   Calls `G6513` to execute the multi-point probing.
    *   Extracts the probed X/Y coordinates from `global.mosMI`.
    *   Calculates the bore's center (cX, cY) and average radius (`avgR`) by finding the circumcenter of the three probed points using slopes, midpoints, and perpendicular bisectors.
    *   Updates `global.mosWPCtrPos` and `global.mosWPRad` for the target `workOffset`.
    *   Moves the machine to the calculated center of the bore (`G6550 X{cX} Y{cY}`).
    *   Moves the machine back to `safeZ` height (`G6550 Z{safeZ}`).
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the X and Y origins of the target WCS to the probed center coordinates using `G10 L2 P{wcsNumber} X{cX} Y{cY}`.

### G6500: PROBE WORK PIECE - BORE

*   **Code:** `G6500`
*   **Description:** This is a meta-macro that guides the operator through the process of probing a circular bore. It explains the procedure, gathers necessary input (approximate bore diameter, probing depth, etc.), and then calls the underlying `G6500.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[2]`), it displays a series of `M291` dialogs explaining the bore probe cycle, including how to enter parameters and the importance of jogging.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to enter the `boreDiameter` and `overTravel` distances using `M291`.
    *   Prompts the operator to jog the probe over the approximate center of the bore using `M291` with jogging enabled.
    *   Prompts the operator to enter the `probingDepth`.
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6500.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6501.1: BOSS - EXECUTE

*   **Code:** `G6501.1`
*   **Description:** Probes the outside surface of a circular boss (protruding feature) to accurately determine its X and Y center coordinates. It uses multiple probe points around the boss's circumference and geometric calculations to find the center.
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the boss's center.
    *   `K<start-y>`: The approximate Y position of the boss's center.
    *   `L<start-z>`: The Z position (absolute) from which to start probing (below the top surface).
    *   `Z<probe-z>`: The absolute Z position at which the horizontal probing will occur.
    *   `H<boss-diameter>`: The approximate diameter of the boss.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
    *   `T<clearance>`: (Optional) The clearance distance. Defaults to `global.mosCL`.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `Z`, `H`) and `W`.
    *   Increments `global.mosPRST` (probe surfaces total) and `global.mosPRPT` (probe points total) for status reporting.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (center, rotation, radius) for the target `workOffset` using `M5010`.
    *   Sets `safeZ` to the `L` parameter.
    *   Calculates the effective `clearance` and `overtravel` by adding/subtracting the tool radius, and determines the `bR` (boss radius).
    *   Generates three probe points equally spaced around the boss's circumference. Each point includes a start position (offset by `bR + clearance`) and a target position (offset by `bR - overtravel`).
    *   Calls `G6513` to execute the multi-point probing.
    *   Extracts the probed X/Y coordinates from `global.mosMI`.
    *   Calculates the boss's center (cX, cY) and average radius (`avgR`) by finding the circumcenter of the three probed points using slopes, midpoints, and perpendicular bisectors.
    *   Updates `global.mosWPCtrPos` and `global.mosWPRad` for the target `workOffset`.
    *   Confirms the machine is at `safeZ` height (`G6550 Z{safeZ}`).
    *   Moves the machine to the calculated center of the boss (`G6550 X{cX} Y{cY}`).
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the X and Y origins of the target WCS to the probed center coordinates using `G10 L2 P{wcsNumber} X{cX} Y{cY}`.

### G6501: PROBE WORK PIECE - BOSS

*   **Code:** `G6501`
*   **Description:** This is a meta-macro that guides the operator through the process of probing a circular boss. It explains the procedure, gathers necessary input (approximate boss diameter, clearance, overtravel, probing depth), and then calls the underlying `G6501.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[3]`), it displays a series of `M291` dialogs explaining the boss probe cycle, including how to enter parameters and the importance of jogging.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to enter the `bossDiameter`, `clearance`, and `overtravel` distances using `M291`.
    *   Prompts the operator to jog the probe over the approximate center of the boss using `M291` with jogging enabled.
    *   Prompts the operator to enter the `probingDepth`.
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6501.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6502.1: RECTANGLE POCKET - EXECUTE

*   **Code:** `G6502.1`
*   **Description:** Probes the X and Y edges of a rectangular pocket (recessed feature) to determine its dimensions, squareness, and center coordinates. It can also calculate the rotation of the pocket relative to the machine axes.
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the pocket's center.
    *   `K<start-y>`: The approximate Y position of the pocket's center.
    *   `L<start-z>`: The Z position (absolute) from which to start probing.
    *   `Z<probe-z>`: The absolute Z position at which the horizontal probing will occur (inside the pocket).
    *   `H<approx-width>`: The approximate width of the pocket along the X-axis.
    *   `I<approx-length>`: The approximate length of the pocket along the Y-axis.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
    *   `T<surface-clearance>`: (Optional) The clearance distance from the surfaces. Defaults to `global.mosCL`.
    *   `C<corner-clearance>`: (Optional) The clearance distance from the corners. Defaults to `global.mosCL` or `T`.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `Z`, `H`, `I`) and `W`, `T`, `C`, `O`.
    *   Increments `global.mosPRST` (probe surfaces total) by 4 and `global.mosPRPT` (probe points total) by 8 for status reporting.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (center, dimensions, rotation) for the target `workOffset` using `M5010`.
    *   Sets `safeZ` to the `L` parameter.
    *   Calculates `surfaceClearance`, `cornerClearance`, and `overtravel`, adjusting for tool radius.
    *   Checks if `cornerClearance` is too large relative to the pocket's dimensions, aborting if it would cause probing outside the pocket.
    *   Generates probe points for two X surfaces (two points per surface, offset by `surfaceClearance` and `overtravel`).
    *   Calls `G6513` to probe the X surfaces.
    *   Calculates `dXAngleDiff` from the probed X surfaces to check for parallelism. Aborts if the surfaces are not parallel within `global.mosAngleTol`.
    *   Recalculates `sX` (center X) based on the probed X surfaces.
    *   Generates probe points for two Y surfaces (two points per surface).
    *   Calls `G6513` to probe the Y surfaces.
    *   Calculates `dYAngleDiff` from the probed Y surfaces to check for parallelism. Aborts if the surfaces are not parallel within `global.mosAngleTol`.
    *   Calculates `cornerAngleError` between the X and Y surfaces to check for perpendicularity. Aborts if not perpendicular within `global.mosAngleTol`.
    *   Updates `global.mosWPCnrDeg` with the corner angle.
    *   Calculates `sY` (center Y) based on the probed Y surfaces.
    *   Sets `global.mosWPCtrPos` (center X,Y) and `global.mosWPDims` (width, length) for the target `workOffset`.
    *   Calculates `global.mosWPDimsErr` (error in dimensions).
    *   Ensures the machine is at `safeZ` height (`G6550 Z{safeZ}`).
    *   Moves the machine to the calculated center of the pocket (`G6550 X{sX} Y{sY}`).
    *   Calculates and sets `global.mosWPDeg` (rotation of the pocket) based on the X surface angle.
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the X and Y origins of the target WCS to the probed center coordinates using `G10 L2 P{wcsNumber} X{sX} Y{sY}`.

### G6502: PROBE WORK PIECE - RECTANGLE POCKET

*   **Code:** `G6502`
*   **Description:** This is a meta-macro that guides the operator through the process of probing a rectangular pocket. It explains the procedure, gathers necessary input (approximate width, length, clearance, overtravel, probing depth), and then calls the underlying `G6502.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[6]`), it displays a series of `M291` dialogs explaining the rectangular pocket probe cycle, including how to enter parameters and the importance of jogging.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to enter the `pocketWidth` and `pocketLength` using `M291`. It attempts to pre-fill these values from `global.mosWPDims` if available.
    *   Prompts for `surfaceClearance` and `overtravel` distances.
    *   If the `surfaceClearance` is too large (more than half the minimum dimension of the pocket), it prompts for a specific `cornerClearance`.
    *   Prompts the operator to jog the probe over the approximate center of the pocket using `M291` with jogging enabled.
    *   Prompts the operator to enter the `probingDepth`.
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6502.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6503.1: RECTANGLE BLOCK - EXECUTE

*   **Code:** `G6503.1`
*   **Description:** Probes the X and Y edges of a rectangular block (protruding feature) to determine its dimensions, squareness, and center coordinates. It can also calculate the rotation of the block relative to the machine axes.
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the block's center.
    *   `K<start-y>`: The approximate Y position of the block's center.
    *   `L<start-z>`: The Z position (absolute) from which to start probing.
    *   `Z<probe-z>`: The absolute Z position at which the horizontal probing will occur (below the top surface).
    *   `H<approx-width>`: The approximate width of the block along the X-axis.
    *   `I<approx-length>`: The approximate length of the block along the Y-axis.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
    *   `T<surface-clearance>`: (Optional) The clearance distance from the surfaces. Defaults to `global.mosCL`.
    *   `C<corner-clearance>`: (Optional) The clearance distance from the corners. Defaults to `global.mosCL` or `T`.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `Z`, `H`, `I`) and `W`, `T`, `C`, `O`.
    *   Increments `global.mosPRST` (probe surfaces total) by 4 and `global.mosPRPT` (probe points total) by 8 for status reporting.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (center, dimensions, rotation) for the target `workOffset` using `M5010`.
    *   Sets `safeZ` to the `L` parameter.
    *   Calculates `surfaceClearance`, `cornerClearance`, and `overtravel`, adjusting for tool radius.
    *   Checks if `cornerClearance` is too large relative to the block's dimensions, aborting if it would cause probing outside the block.
    *   Generates probe points for two X surfaces (two points per surface, offset by `surfaceClearance` and `overtravel`).
    *   Calls `G6513` to probe the X surfaces.
    *   Calculates `dXAngleDiff` from the probed X surfaces to check for parallelism. Aborts if the surfaces are not parallel within `global.mosAngleTol`.
    *   Recalculates `sX` (center X) based on the probed X surfaces.
    *   Generates probe points for two Y surfaces (two points per surface).
    *   Calls `G6513` to probe the Y surfaces.
    *   Calculates `dYAngleDiff` from the probed Y surfaces to check for parallelism. Aborts if the surfaces are not parallel within `global.mosAngleTol`.
    *   Calculates `cornerAngleError` between the X and Y surfaces to check for perpendicularity. Aborts if not perpendicular within `global.mosAngleTol`.
    *   Updates `global.mosWPCnrDeg` with the corner angle.
    *   Recalculates `sY` (center Y) based on the probed Y surfaces.
    *   Sets `global.mosWPCtrPos` (center X,Y) and `global.mosWPDims` (width, length) for the target `workOffset`.
    *   Calculates `global.mosWPDimsErr` (error in dimensions).
    *   Ensures the machine is at `safeZ` height (`G6550 Z{safeZ}`).
    *   Moves the machine to the calculated center of the block (`G6550 X{sX} Y{sY}`).
    *   Calculates and sets `global.mosWPDeg` (rotation of the block) based on the X surface angle.
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the X and Y origins of the target WCS to the probed center coordinates using `G10 L2 P{wcsNumber} X{sX} Y{sY}`.

### G6503: PROBE WORK PIECE - RECTANGLE BLOCK

*   **Code:** `G6503`
*   **Description:** This is a meta-macro that guides the operator through the process of probing a rectangular block. It explains the procedure, gathers necessary input (approximate width, length, clearance, overtravel, probing depth), and then calls the underlying `G6503.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed center will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[5]`), it displays a series of `M291` dialogs explaining the rectangular block probe cycle, including how to enter parameters and the importance of jogging.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to enter the `blockWidth` and `blockLength` using `M291`. It attempts to pre-fill these values from `global.mosWPDims` if available.
    *   Prompts for `surfaceClearance` and `overtravel` distances.
    *   If the `surfaceClearance` is too large (more than half the minimum dimension of the block), it prompts for a specific `cornerClearance`.
    *   Prompts the operator to jog the probe over the approximate center of the block using `M291` with jogging enabled.
    *   Prompts the operator to enter the `probingDepth`.
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6503.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6504.1: WEB - EXECUTE

*   **Code:** `G6504.1`
*   **Description:** Probes the X or Y edges of a web (a protruding feature) to determine its midpoint and dimensions along the probed axis. It supports both "Full" mode (two points per surface for parallelism and rotation) and "Quick" mode (one point per surface for a simple midpoint).
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the web's midpoint.
    *   `K<start-y>`: The approximate Y position of the web's midpoint.
    *   `L<start-z>`: The Z position (absolute) from which to start probing.
    *   `Z<probe-z>`: The absolute Z position at which the horizontal probing will occur.
    *   `N<axis>`: The axis along which the web is oriented (0 for X, 1 for Y).
    *   `H<approx-width>`: The approximate width of the web along the `N` axis.
    *   `Q<mode>`: (Optional) Probing mode: `0` for Full (two points per surface), `1` for Quick (one point per surface). Defaults to Quick.
    *   `I<approx-length>`: (Required in Full mode) The approximate length of the web along the axis perpendicular to `N`.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed midpoint will be assigned as the origin. Defaults to the current workplace number.
    *   `T<surface-clearance>`: (Optional) The clearance distance from the surfaces. Defaults to `global.mosCL`.
    *   `C<edge-clearance>`: (Optional) The clearance distance from the edges (used in Full mode). Defaults to `global.mosCL` or `T`.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `Z`, `N`, `H`) and `Q`, `I`, `W`, `T`, `C`, `O`.
    *   Increments `global.mosPRST` (probe surfaces total) by 2 and `global.mosPRPT` (probe points total) by 4 (Full mode) or 2 (Quick mode) for status reporting.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (center, dimensions, rotation) for the target `workOffset` using `M5010`.
    *   Sets `safeZ` to the `L` parameter.
    *   Calculates `surfaceClearance`, `edgeClearance`, and `overtravel`, adjusting for tool radius.
    *   In Full mode, checks if `edgeClearance` is too large relative to the web's length, aborting if it would cause probing outside the web.
    *   Generates probe points for two surfaces of the web. The number of points per surface depends on `Q` (Full/Quick mode).
    *   Calls `G6513` to execute the multi-point probing.
    *   Retrieves the probed surface data from `global.mosMI`.
    *   **Quick Mode:** Calculates `global.mosWPCtrPos` (midpoint) and `global.mosWPDims` (width) along the probed axis based on the two probed points.
    *   **Full Mode:**
        *   Calculates `rAngleDiff` to check for parallelism of the web surfaces. Aborts if not parallel within `global.mosAngleTol`.
        *   Calculates `global.mosWPCtrPos` (midpoint) and `global.mosWPDims` (width) along the probed axis based on all four probed points.
        *   Calculates and sets `global.mosWPDeg` (rotation of the web) based on the surface angle.
    *   Ensures the machine is at `safeZ` height (`G6550 Z{safeZ}`).
    *   Moves the machine to the calculated midpoint of the web (`G6550 X{cX} Y{cY}`).
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the X or Y origin of the target WCS to the web's midpoint using `G10 L2 P{wcsNumber} X{cX}` or `Y{cY}`.

### G6504: PROBE WORK PIECE - WEB

*   **Code:** `G6504`
*   **Description:** This is a meta-macro that guides the operator through the process of probing a web (protruding feature). It explains the procedure, gathers necessary input (probing mode, orientation, approximate width, optional length, clearance, overtravel, probing depth), and then calls the underlying `G6504.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed midpoint will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[6]`), it displays a series of `M291` dialogs explaining the web probe cycle, including how to enter parameters and the importance of jogging.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to select the probing `mode` (Full/Quick) and `axis` (X/Y) using `M291`.
    *   Prompts for the `webWidth`.
    *   If in Full mode, it prompts for the `webLength`.
    *   Prompts for `surfaceClearance` and `overtravel` distances.
    *   If in Full mode and `surfaceClearance` is too large, it prompts for a specific `edgeClearance`.
    *   Prompts the operator to jog the probe over the approximate midpoint of the web using `M291` with jogging enabled.
    *   Prompts the operator to enter the `probingDepth`.
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6504.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6505.1: POCKET - EXECUTE

*   **Code:** `G6505.1`
*   **Description:** Probes the X or Y edges of a pocket (a recessed feature) to determine its midpoint and dimensions along the probed axis. It supports both "Full" mode (two points per surface for parallelism and rotation) and "Quick" mode (one point per surface for a simple midpoint). This macro is similar to `G6504.1` but for pockets.
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the pocket's midpoint.
    *   `K<start-y>`: The approximate Y position of the pocket's midpoint.
    *   `L<start-z>`: The Z position (absolute) from which to start probing.
    *   `Z<probe-z>`: The absolute Z position at which the horizontal probing will occur (inside the pocket).
    *   `N<axis>`: The axis along which the pocket is oriented (0 for X, 1 for Y).
    *   `H<approx-width>`: The approximate width of the pocket along the `N` axis.
    *   `Q<mode>`: (Optional) Probing mode: `0` for Full (two points per surface), `1` for Quick (one point per surface). Defaults to Quick.
    *   `I<approx-length>`: (Required in Full mode) The approximate length of the pocket along the axis perpendicular to `N`.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed midpoint will be assigned as the origin. Defaults to the current workplace number.
    *   `T<surface-clearance>`: (Optional) The clearance distance from the surfaces. Defaults to `global.mosCL`.
    *   `C<edge-clearance>`: (Optional) The clearance distance from the edges (used in Full mode). Defaults to `global.mosCL` or `T`.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `Z`, `N`, `H`) and `Q`, `I`, `W`, `T`, `C`, `O`.
    *   Increments `global.mosPRST` (probe surfaces total) by 2 and `global.mosPRPT` (probe points total) by 4 (Full mode) or 2 (Quick mode) for status reporting.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (center, dimensions, rotation) for the target `workOffset` using `M5010`.
    *   Sets `safeZ` to the `L` parameter.
    *   Calculates `surfaceClearance`, `edgeClearance`, and `overtravel`, adjusting for tool radius.
    *   In Full mode, checks if `edgeClearance` is too large relative to the pocket's length, aborting if it would cause probing outside the pocket.
    *   Generates probe points for two surfaces of the pocket. The number of points per surface depends on `Q` (Full/Quick mode).
    *   Moves down into the pocket to `param.Z` (`G6550 Z{param.Z}`).
    *   Calls `G6513` to execute the multi-point probing.
    *   Retrieves the probed surface data from `global.mosMI`.
    *   **Quick Mode:** Calculates `global.mosWPCtrPos` (midpoint) and `global.mosWPDims` (width) along the probed axis based on the two probed points.
    *   **Full Mode:**
        *   Calculates `rAngleDiff` to check for parallelism of the pocket surfaces. Aborts if not parallel within `global.mosAngleTol`.
        *   Calculates `global.mosWPCtrPos` (midpoint) and `global.mosWPDims` (width) along the probed axis based on all four probed points.
        *   Calculates and sets `global.mosWPDeg` (rotation of the pocket) based on the surface angle.
    *   Moves the machine to the calculated midpoint of the pocket (`G6550 X{cX} Y{cY}`).
    *   Retracts the machine to `safeZ` height (`G6550 Z{safeZ}`).
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the X or Y origin of the target WCS to the pocket's midpoint using `G10 L2 P{wcsNumber} X{cX}` or `Y{cY}`.

### G6505: PROBE WORK PIECE - POCKET

*   **Code:** `G6505`
*   **Description:** This is a meta-macro that guides the operator through the process of probing a pocket (recessed feature). It explains the procedure, gathers necessary input (probing mode, orientation, approximate width, optional length, clearance, overtravel, probing depth), and then calls the underlying `G6505.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed midpoint will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[6]`), it displays a series of `M291` dialogs explaining the pocket probe cycle, including how to enter parameters and the importance of jogging.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to select the probing `mode` (Full/Quick) and `axis` (X/Y) using `M291`.
    *   Prompts for the `pocketWidth`.
    *   If in Full mode, it prompts for the `pocketLength`.
    *   Prompts for `surfaceClearance` and `overtravel` distances.
    *   If in Full mode and `surfaceClearance` is too large, it prompts for a specific `edgeClearance`.
    *   Prompts the operator to jog the probe over the approximate midpoint of the pocket using `M291` with jogging enabled.
    *   Prompts the operator to enter the `probingDepth`.
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6505.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6508.1: OUTSIDE CORNER PROBE - EXECUTE

*   **Code:** `G6508.1`
*   **Description:** Probes an outside corner of a workpiece to determine its X and Y coordinates. It can also calculate the corner angle and workpiece rotation in "Full" mode. The probed corner position can then be used to set the origin of a Work Coordinate System (WCS).
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the probe above the corner.
    *   `K<start-y>`: The approximate Y position of the probe above the corner.
    *   `L<start-z>`: The Z position (absolute) from which to start probing.
    *   `Z<probe-z>`: The absolute Z position at which the horizontal probing will occur (below the top surface).
    *   `N<corner-index>`: The 0-indexed identifier for the corner being probed (0-3, typically representing front-left, front-right, back-right, back-left relative to the operator).
    *   `Q<mode>`: (Optional) Probing mode: `0` for Full (two points per surface), `1` for Quick (one point per surface). Defaults to Quick.
    *   `H<approx-x-length>`: (Required in Full mode) The approximate length of the surface forming the corner along the X-axis.
    *   `I<approx-y-length>`: (Required in Full mode) The approximate length of the surface forming the corner along the Y-axis.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed corner will be assigned as the origin. Defaults to the current workplace number.
    *   `T<surface-clearance>`: (Optional) The clearance distance from the surfaces. Defaults to `global.mosCL`.
    *   `C<corner-clearance>`: (Optional) The clearance distance from the corners. Defaults to `global.mosCL` or `T`.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `Z`, `N`) and `Q`, `H`, `I`, `W`, `T`, `C`, `O`.
    *   Increments `global.mosPRST` (probe surfaces total) by 1 or 2 and `global.mosPRPT` (probe points total) by 2 or 4 for status reporting, depending on `Q` (Full/Quick mode).
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (corner, dimensions, rotation) for the target `workOffset` using `M5010`.
    *   Sets `safeZ` to the `L` parameter.
    *   Calculates `surfaceClearance`, `cornerClearance`, and `overtravel`, adjusting for tool radius.
    *   In Full mode, checks if `cornerClearance` is too large relative to the surface lengths, aborting if it would cause probing outside the workpiece.
    *   Generates probe points for the two surfaces forming the corner. The number of points per surface depends on `Q` (Full/Quick mode).
    *   Calls `G6513` to execute the multi-point probing.
    *   Retrieves the probed surface data from `global.mosMI`.
    *   **Quick Mode:** Sets `cX` and `cY` (corner X,Y) directly from the first probed points of each surface. Assumes a 90-degree corner.
    *   **Full Mode:**
        *   Extracts probed points and surface angles.
        *   Calculates `global.mosWPCnrDeg` (corner angle) from the difference in surface angles.
        *   Calculates `global.mosWPDeg` (workpiece rotation) based on the longer surface's angle.
        *   Calculates the intersection point (cX, cY) of the two probed lines using their slopes and intercepts.
        *   Calculates `global.mosWPCtrPos` (workpiece center) and `global.mosWPDims` (workpiece dimensions) based on the corner and rotation.
    *   Sets `global.mosWPCnrPos` (probed corner X,Y) and `global.mosWPCnrNum` (corner index) for the target `workOffset`.
    *   Ensures the machine is at `safeZ` height (`G6550 Z{safeZ}`).
    *   Moves the machine above the calculated corner position (`G6550 X{cX} Y{cY}`).
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the X and Y origins of the target WCS to the probed corner coordinates using `G10 L2 P{wcsNumber} X{cX} Y{cY}`.

### G6508: PROBE WORK PIECE - OUTSIDE CORNER

*   **Code:** `G6508`
*   **Description:** This is a meta-macro that guides the operator through the process of probing an outside corner of a workpiece. It explains the procedure, gathers necessary input (probing mode, approximate surface lengths, clearance, overtravel, corner selection, probing depth), and then calls the underlying `G6508.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed corner will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[10]`), it displays a series of `M291` dialogs explaining the outside corner probe cycle, including Full/Quick modes, parameter entry, and jogging instructions.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to select the probing `mode` (Full/Quick) using `M291`.
    *   If in Full mode, it prompts for the approximate `xSL` (X surface length) and `ySL` (Y surface length).
    *   Prompts for `surfaceClearance` and `overtravel` distances.
    *   If in Full mode and `surfaceClearance` is too large, it prompts for a specific `cornerClearance`.
    *   Prompts the operator to jog the probe over the corner to be probed using `M291` with jogging enabled.
    *   Prompts the operator to select the `cnr` (corner index) and enter the `probingDepth`.
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6508.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6510.1: SINGLE SURFACE PROBE - EXECUTE

*   **Code:** `G6510.1`
*   **Description:** Executes a single surface probe operation. Given a starting position, an axis to probe along, and a distance, it moves the probe towards a target surface until contact is made or the probe distance is exceeded. The probed position can then be used to set a WCS origin.
*   **Arguments:**
    *   `J<start-x>`: The X position from which to start the probe.
    *   `K<start-y>`: The Y position from which to start the probe.
    *   `L<start-z>`: The Z position from which to start the probe.
    *   `H<probe-axis>`: The axis and direction to probe:
        *   `0`: X+ (positive X direction)
        *   `1`: X- (negative X direction)
        *   `2`: Y+ (positive Y direction)
        *   `3`: Y- (negative Y direction)
        *   `4`: Z- (negative Z direction)
    *   `I<probe-distance>`: The maximum distance to probe towards the target surface. If the probe is not triggered within this distance, an error may occur.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed surface position will be assigned as the origin. Defaults to the current workplace number.
    *   `O<overtravel>`: (Optional) The overtravel distance. Defaults to `global.mosOT`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `H`, `I`) and `W`, `O`.
    *   Increments `global.mosPRST` (probe surfaces total) and `global.mosPRPT` (probe points total) by 1 for status reporting.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Resets relevant WCS probe details (surface and rotation) for the target `workOffset` using `M5010`.
    *   Retrieves the current machine's Z position for `safeZ`.
    *   Calculates the `overtravel` distance (tool radius is not applied to Z probes).
    *   Calculates the target positions (`tPX`, `tPY`, `tPZ`) based on the `probeAxis`, `probeDist`, `overtravel`, and tool radius (`tR`).
    *   Checks if the calculated target positions are within machine limits using `M6515`.
    *   Constructs a single probe point array for `G6513`.
    *   Calls `G6513` to execute the probing operation.
    *   Determines the probed axis (`sAxis`) and sets `global.mosWPSfcAxis` and `global.mosWPSfcPos` for the target `workOffset` based on the result from `global.mosMI`.
    *   If `R0` is not present, it reports the probe results using `M7601`.
    *   Sets the origin of the target WCS for the probed axis (X, Y, or Z) to the probed surface position using `G10 L2 P{wcsNumber} X{pos}`, `Y{pos}`, or `Z{pos}`.

### G6510: SINGLE SURFACE PROBE

*   **Code:** `G6510`
*   **Description:** This is a meta-macro that guides the operator through the process of performing a single surface probe. It explains the procedure, gathers necessary input (overtravel, axis to probe, probing depth for X/Y, probe distance), and then calls the underlying `G6510.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed surface position will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[4]`), it displays a series of `M291` dialogs explaining the single surface probe cycle, including cautions about perpendicularity, jogging, and probe movement.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to enter the `overtravel` distance using `M291`.
    *   Prompts the operator to jog the probe or tool to their chosen starting position using `M291` with jogging enabled.
    *   Prompts the operator to select the `probeAxis` (surface to probe) from a list of options.
    *   If the selected `probeAxis` is for X or Y, it prompts for the `probeDepth` (how far to move down before horizontal probing).
    *   Prompts the operator to enter the `probeDist` (distance to probe towards the surface).
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6510.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6511: REFERENCE SURFACE PROBE - EXECUTE

*   **Code:** `G6511`
*   **Description:** Probes a designated reference surface on the machine. This reference surface serves as a known Z-height datum, crucial for accurate offset calculations for tools and workpiece surfaces, especially when using a toolsetter and touch probe in conjunction.
*   **Arguments:**
    *   `R1`: (Optional) If present, forces a re-probe of the reference surface even if `global.mosTSAP` (toolsetter activation point) is already set.
    *   `S0`: (Optional) If present, indicates that the macro is being called in a "non-standalone" mode (e.g., from within a tool change macro). In this mode, it will *not* attempt to switch tools.
*   **How it works:**
    *   Sets absolute positioning (`G90`), millimeters as units (`G21`), and feed rate mode (`G94`).
    *   If neither `global.mosFeatTouchProbe` nor `global.mosFeatToolSetter` are enabled, the macro exits silently as the reference surface is not needed.
    *   If `global.mosTSAP` is already set and `R1` is not provided, it echoes a message and exits, preventing unnecessary re-probing.
    *   If `S0` is *not* present (standalone mode) and the current tool is not the probe tool (`global.mosPTID`), it attempts to switch to the probe tool (`T{global.mosPTID}`) and then exits, expecting to be re-called with `S0` after the tool change.
    *   Resets `global.mosTSAP` to `null`.
    *   Performs a Z-axis probe downwards using `G6512` with the touch probe (`global.mosTPID`) at the `global.mosTPRP` (touch probe reference position) X/Y coordinates, from `move.axes[2].max` towards `move.axes[2].min`.
    *   Calculates `global.mosTSAP` by subtracting the difference between the touch probe's reference Z and the toolsetter's reference Z from the probed Z-height. This establishes the toolsetter activation point relative to the reference surface.
    *   If not in expert mode (`global.mosEM`), it echoes the probed reference surface Z and the calculated toolsetter activation point Z.

### G6512.1: SINGLE SURFACE PROBE - EXECUTE WITH PROBE

*   **Code:** `G6512.1`
*   **Description:** Performs a repeatable, automated single surface probe in any direction using a configured probe. This macro is designed to be called by higher-level macros that handle parameter validation. It includes logic for multiple retries and statistical analysis of probed points to improve accuracy.
*   **Arguments:**
    *   `I<probe-id>`: The ID of the probe to use for the operation.
    *   `X<target-x>`: The target X position for the probe move.
    *   `Y<target-y>`: The target Y position for the probe move.
    *   `Z<target-z>`: The target Z position for the probe move.
    *   `R<retries>`: (Optional) The maximum number of times to retry the probe. Defaults to `sensors.probes[I].maxProbeCount + 1`.
    *   `E0`: (Optional) If present, disables error reporting if the probe does not activate by the time it reaches the target position. This is useful for operations where non-activation is expected or handled externally.
*   **How it works:**
    *   Validates the `I` parameter (probe ID) and ensures it's a valid probe type (5 or 8). Also validates that at least one target position (`X`, `Y`, or `Z`) is provided.
    *   Sets absolute positioning (`G90`), millimeters as units (`G21`), and feed rate mode (`G94`).
    *   Cancels rotation compensation (`G69`) to avoid interference with `G53` moves.
    *   Initializes `global.mosPRRT` (probe retries total) and `global.mosPRRS` (probe retries remaining).
    *   Retrieves the current machine position using `M5000 P0`.
    *   Sets `sP` (start position) and `tP` (target position), using current position for unset target coordinates.
    *   Checks if target positions are within machine limits using `M6515`.
    *   Retrieves `roughSpeed` and `fineSpeed` from the probe's configuration. If only one speed is configured, `fineSpeed` is derived.
    *   Initializes variables (`cP`, `oM`, `oS`, `nD`, `nM`, `nS`, `pV`) for calculating average positions and variances of probed points.
    *   Enters a loop that runs for the specified number of `retries` or until the probed position is within tolerance:
        *   Executes a protected probe move using `G53 G38.2` (with error if `E0` is not present) or `G53 G38.3` (without error) towards the target position.
        *   If an error occurs during `G38.2`, it parks the spindle in Z (`G27 Z1`) and aborts.
        *   Retrieves the current machine position (`M5000 P0`) after the probe.
        *   Updates `cP` (current position).
        *   Calculates the mean and cumulative variance for each axis based on the current and previous probed points.
        *   Switches to `fineSpeed` after the first probe.
        *   If the probe moved, it backs off from the probed point by `sensors.probes[I].diveHeights` using `G6550`.
        *   Checks if all moved axes are within the probe's `tolerance`. If so, the loop breaks early.
        *   If configured, pauses for `sensors.probes[I].recoveryTime` to allow the machine to settle.
    *   The final calculated average position (`var.nM`) is stored in `global.mosMI`.

### G6512.2: SINGLE SURFACE PROBE - EXECUTE MANUALLY

*   **Code:** `G6512.2`
*   **Description:** Performs a manual single surface probe. This macro guides the operator through successive jogging movements towards a target position until they confirm that the tool is touching the surface. It is designed for situations where an automated probe is not available or desired.
*   **Arguments:**
    *   `X<target-x>`: The target X position for the manual probe.
    *   `Y<target-y>`: The target Y position for the manual probe.
    *   `Z<target-z>`: The target Z position for the manual probe.
*   **How it works:**
    *   Validates that at least one target position (`X`, `Y`, or `Z`) is provided.
    *   Sets absolute positioning (`G90`), millimeters as units (`G21`), and feed rate mode (`G94`).
    *   Cancels rotation compensation (`G69`).
    *   Retrieves the current machine position using `M5000 P0`.
    *   Sets `sP` (start position) and `cP` (current position).
    *   Enters a `while` loop that continues until the operator selects "Finish" or "Cancel":
        *   Calculates the distance (`mag`) between the current position and the target position.
        *   Identifies valid jog distances from `global.mosMPD` (MillenniumOS Manual Probe Distances) that are less than the `mag`.
        *   Displays a dialog (`M291`) showing the current position, distance to target, and a list of selectable jog distances (e.g., "50mm", "10mm", "Finish", "Cancel").
        *   If the operator cancels, the macro aborts.
        *   If the operator selects "Finish" (distance `0`), the loop breaks.
        *   Determines the `moveSpeed` based on the selected jog increment (smaller increments use `global.mosMPS[2]`, larger use `global.mosMPS[1]`).
        *   Calculates the new position based on the selected jog distance and moves the machine using `G53 G1`.
        *   Updates `cP` with the new machine position.
    *   The final confirmed position (`var.cP`) is stored in `global.mosMI`.
    *   If the probe moved from its starting position, it performs a back-off move by `global.mosMPBO` (MillenniumOS Manual Probe Back-Off) using `G6550` to ensure the tool is clear of the workpiece.
    *   Executes `M400` to wait for all moves to finish.

### G6512: SINGLE SURFACE PROBE - MANUAL OR AUTOMATED

*   **Code:** `G6512`
*   **Description:** This is a versatile macro that implements either manual or automated probing of a single surface. It acts as a wrapper, calling `G6512.1` for automated probing (with a specified probe ID) or `G6512.2` for guided manual probing (if no probe ID is provided). It handles initial positioning, safety checks, and tool radius/deflection compensation.
*   **Arguments:**
    *   `I<optional-probe-id>`: (Optional) If present, specifies the ID of the probe to use for automated probing. If omitted or `null`, manual probing is initiated.
    *   `X<target-x>`: The target X coordinate for the probe move.
    *   `Y<target-y>`: The target Y coordinate for the probe move.
    *   `Z<target-z>`: The target Z coordinate for the probe move.
    *   `L<start-coord-z>`: The initial absolute Z height from which to begin the probe move. This is a required parameter.
    *   `J<optional-start-coord-x>`: (Optional) The X coordinate for the starting position. Defaults to the current machine X position if omitted.
    *   `K<optional-start-coord-y>`: (Optional) The Y coordinate for the starting position. Defaults to the current machine Y position if omitted.
    *   `S<safe-z>`: (Optional) A safe absolute Z position to return to after probing. Defaults to the current machine Z position if omitted.
    *   `D1`: (Optional) If present, the machine will *not* move to the `safeZ` height after the probe operation; it will stay at the probed height.
    *   `R<retries>`: (Optional) Number of retries for automated probing (passed to `G6512.1`).
    *   `E0`: (Optional) Disables error reporting for automated probing (passed to `G6512.1`).
*   **How it works:**
    *   Validates that all axes are homed.
    *   Validates the `I` parameter, ensuring it's a valid probe ID if provided.
    *   Determines if `manualProbe` is `true` (no `I` parameter).
    *   Retrieves the current machine position using `M5000 P0`.
    *   Sets `sX`, `sY` (start X,Y), `safeZ`, and `sZ` (start Z) based on parameters and current position.
    *   Validates that target positions (`X`, `Y`, `Z`) and `L` are provided.
    *   Aborts if no tool is currently selected.
    *   Calculates `tPX`, `tPY`, `tPZ` (target positions).
    *   Checks if calculated positions are within machine limits using `M6515`.
    *   Sets absolute positioning (`G90`), millimeters as units (`G21`), and feed rate mode (`G94`).
    *   Performs initial moves to the starting probe height and X/Y position using `G6550`.
    *   If `manualProbe` is `true`, it calls `G6512.2` to execute the manual probe.
    *   Otherwise, it calls `G6512.1` with the probe ID and other parameters for automated probing.
    *   Saves the probed position (from `global.mosMI`) into `pP`.
    *   If `D1` is *not* present, it moves the machine to `safeZ` height using `G6550`.
    *   Executes `M400` to wait for movement to stop.
    *   If `manualProbe` is `false`, it calculates and applies tool radius and deflection compensation to `pP`.
    *   Updates `global.mosPRPS` (probe points success) and `global.mosPRSS` (probe surfaces success).
    *   Sets `global.mosMI` to the final compensated probed position.

### G6513: SURFACE PROBE - MANUAL OR AUTOMATED - MULTIPLE POINTS

*   **Code:** `G6513`
*   **Description:** This advanced macro facilitates probing multiple points across one or more surfaces, either manually or automatically. It leverages `G6512.1` and `G6512.2` internally. It is designed to handle the concept of "surfaces" (each consisting of one or more probe points) and can calculate surface angles and apply compensations based on tool radius and deflection.
*   **Arguments:**
    *   `I<optional-probe-id>`: (Optional) If present, specifies the ID of the probe to use for automated probing. If omitted or `null`, manual probing is initiated.
    *   `P<probe-points-array>`: A nested array defining the surfaces and their probe points. The structure is `{{SURFACE_1}, {SURFACE_2}, ...}`, where each `SURFACE` is an array of `{{start_pos}, {target_pos}}` pairs. Each `pos` is a `[X, Y, Z]` coordinate.
    *   `S<safe-z>`: The absolute Z position to return to between individual probe points (if `D1` is not present) and between surfaces (if `H1` is not present).
    *   `D1`: (Optional) If present, the machine will *not* move to the `safeZ` height after each individual probe point.
    *   `H1`: (Optional) If present, the machine will *not* move to the `safeZ` height after each complete surface has been probed.
    *   `R<retries>`: (Optional) Number of retries for automated probing (passed to `G6512.1`).
    *   `E0`: (Optional) Disables error reporting for automated probing (passed to `G6512.1`).
*   **How it works:**
    *   If `global.mosDebug` is enabled, it echoes debug information about the macro's start and parameters.
    *   Validates that all axes are homed.
    *   Validates the `I` parameter, ensuring it's a valid probe ID if provided.
    *   Determines `probe` (ID or null), `manualProbe`, `retractAfterPoint`, and `retractAfterSurface` based on parameters.
    *   Sets absolute positioning (`G90`), millimeters as units (`G21`), and feed rate mode (`G94`).
    *   Retrieves the current machine position (`M5000 P0`).
    *   Sets `safeZ` based on the `S` parameter or current Z.
    *   Validates the `P` parameter (probe points array), ensuring it's not empty and contains a maximum of 2 points per surface.
    *   Aborts if no tool is currently selected.
    *   Initializes `pSfc` (a vector to store probed surface data, including points, approach angle, and surface angle).
    *   Calculates `trX` and `trY` (tool radius minus deflection for X and Y compensation).
    *   **Surface and Point Iteration:**
        *   It iterates through each `surface` in `param.P`.
        *   For each `surface`, it iterates through each `point` defined within it:
            *   Extracts `startPos` and `targetPos`.
            *   Checks if these positions are within machine limits using `M6515`.
            *   Moves the machine to the `startPos` (Z first, then X/Y) using `G6550`.
            *   If `manualProbe`, it calls `G6512.2`. Otherwise, it calls `G6512.1` with the probe ID and other parameters.
            *   Retrieves the `probedPos` from `global.mosMI`.
            *   Calculates the `rApproachCur` (current approach angle) and accumulates it for the surface.
            *   Stores the `probedPos` and updates the `surface angle` (initially perpendicular to approach, then refined with two points).
            *   Moves back to `startPos` and, if `retractAfterPoint`, moves to `safeZ` using `G6550`.
            *   Updates `global.mosPRPS`.
        *   If `retractAfterSurface`, it moves to `safeZ` using `G6550`.
        *   Updates `global.mosPRSS`.
    *   **Compensation Application:** After all points are probed, it iterates through the `pSfc` data to apply tool radius and deflection compensation to each probed point. This involves:
        *   Calculating unit vectors for approach, surface, and surface normal directions.
        *   Calculating the dot product between the approach and normal vectors.
        *   Calculating `effectiveDeflection` and `compMagnitude`.
        *   Calculating `dX` and `dY` (compensation in X and Y).
        *   Adjusting the X and Y coordinates of each `probedPos` in `pSfc` by `dX` and `dY`.
    *   The final compensated `pSfc` data is stored in `global.mosMI`.
    *   If `global.mosDebug` is enabled, it echoes debug information about the compensation and the final output.

### G6520.1: VISE CORNER - EXECUTE

*   **Code:** `G6520.1`
*   **Description:** This macro performs a comprehensive probing operation to establish the X, Y, and Z origins of a Work Coordinate System (WCS) at a workpiece corner, typically in a vise. It first probes the top surface for Z, then probes the two adjacent corner surfaces for X and Y.
*   **Arguments:**
    *   `J<start-x>`: The approximate X position of the probe above the corner.
    *   `K<start-y>`: The approximate Y position of the probe above the corner.
    *   `L<start-z>`: The Z position (absolute) from which to start probing.
    *   `P<probe-depth>`: The depth, in millimeters, below the probed top surface at which the horizontal corner surfaces will be probed.
    *   `N<corner-index>`: The 0-indexed identifier for the corner being probed (0-3).
    *   `Q<mode>`: (Optional) Probing mode: `0` for Full, `1` for Quick. Passed directly to `G6508.1`.
    *   `H<approx-x-length>`: (Required in Full mode) Approximate X length of the surface forming the corner. Passed to `G6508.1`.
    *   `I<approx-y-length>`: (Required in Full mode) Approximate Y length of the surface forming the corner. Passed to `G6508.1`.
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed corner will be assigned as the origin. Defaults to the current workplace number.
    *   `T<surface-clearance>`: (Optional) Clearance distance from surfaces. Passed to `G6510.1` and `G6508.1`.
    *   `C<corner-clearance>`: (Optional) Clearance distance from corners. Passed to `G6508.1`.
    *   `O<overtravel>`: (Optional) Overtravel distance. Passed to `G6510.1` and `G6508.1`.
    *   `R0`: (Optional) If present, suppresses the reporting of probe results to the console.
*   **How it works:**
    *   Validates all required parameters (`J`, `K`, `L`, `P`, `N`) and `Q`, `H`, `I`, `W`, `T`, `C`, `O`.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Calls `G6510.1` (single surface probe) to probe the top Z surface of the workpiece. `R0` is passed to suppress its individual reporting.
    *   Aborts if the Z surface probe fails or if the probed axis is not Z.
    *   Retrieves the current machine position's Z coordinate using `M5000 P1 I2`.
    *   Calls `G6508.1` (outside corner probe) to probe the X and Y surfaces forming the corner. `R0` is passed to suppress its individual reporting. The `Z` parameter for `G6508.1` is calculated as `global.mosWPSfcPos[var.workOffset] - param.P`, ensuring probing occurs at the specified depth below the top surface.
    *   Aborts if the corner probe fails.
    *   If `R0` is not present, it reports the combined probe results for the target `workOffset` using `M7601`.

### G6520: PROBE WORK PIECE - VISE CORNER

*   **Code:** `G6520`
*   **Description:** This is a meta-macro that guides the operator through the process of probing a workpiece corner, typically held in a vise. It explains the procedure, gathers necessary input (probing mode, approximate surface lengths, clearance, overtravel, corner selection, probing depth), and then calls the underlying `G6520.1` macro to execute the actual probe cycle.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to which the probed corner will be assigned as the origin. Defaults to the current workplace number.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[11]`), it displays a series of `M291` dialogs explaining the vise corner probe cycle, including Full/Quick modes, parameter entry, and jogging instructions.
    *   Ensures the probe tool (`global.mosPTID`) is currently selected.
    *   Prompts the operator to select the probing `mode` (Full/Quick) using `M291`.
    *   If in Full mode, it prompts for the approximate `xSL` (X surface length) and `ySL` (Y surface length).
    *   Prompts for `surfaceClearance` and `overtravel` distances.
    *   If in Full mode and `surfaceClearance` is too large, it prompts for a specific `cornerClearance`.
    *   Prompts the operator to jog the probe over the corner to be probed using `M291` with jogging enabled.
    *   Prompts the operator to select the `cnr` (corner index) and enter the `probeDepth` (depth below the top surface for horizontal probing).
    *   If `global.mosTM` is enabled, it displays a final confirmation dialog before proceeding.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calls `G6520.1` with all the collected parameters, including the current machine X, Y, and Z positions as the starting point, and the calculated probing depth.

### G6550: PROTECTED MOVE - EXECUTE

*   **Code:** `G6550`
*   **Description:** Executes a "protected move," which is similar to a standard `G1` linear move but incorporates collision detection using a specified probe. This is critical during probing operations to prevent damage to the workpiece, fixtures, or the probe itself, especially when relying on operator input for target positions.
*   **Arguments:**
    *   `I<probe-id>`: The ID of the probe to use for collision detection during the move. If omitted or `null`, the move will be executed without probe protection (like a standard `G1`).
    *   `X<target-x>`: The target X position for the move.
    *   `Y<target-y>`: The target Y position for the move.
    *   `Z<target-z>`: The target Z position for the move.
*   **How it works:**
    *   Validates the `I` parameter (probe ID) and ensures it's a valid probe type (5 or 8). Also validates that at least one target position (`X`, `Y`, or `Z`) is provided.
    *   Determines if `manualProbe` is `true` (no `I` parameter).
    *   Sets absolute positioning (`G90`), millimeters as units (`G21`), and feed rate mode (`G94`).
    *   Cancels rotation compensation (`G69`) to avoid interference with `G53` moves.
    *   Retrieves the current machine position using `M5000 P0`.
    *   Calculates `tPX`, `tPY`, `tPZ` (target positions), using current position for unset target coordinates.
    *   If the target position is identical to the current position, the macro exits silently.
    *   Checks if target positions are within machine limits using `M6515`.
    *   **Unprotected Move:** If `manualProbe` is `true`, it executes a standard `G53 G1` move to the target position using `global.mosMPS[0]` (manual probing travel speed) and then exits.
    *   **Positive Z Move:** If the move is only in the positive Z direction, it executes a standard `G53 G1` move using `sensors.probes[param.I].travelSpeed` and exits (as vertical upward moves are generally safe).
    *   **Probe Already Triggered:** If the probe is already triggered (`sensors.probes[param.I].value[0] != 0`):
        *   It calculates a back-off target position by `global.mosPMBO` (MillenniumOS Protected Move Back-Off) along the vector towards the target.
        *   It executes a `G53 G1` move to this back-off position.
        *   Waits for moves to complete (`M400`).
        *   If the probe is *still* triggered after backing off, it aborts with a critical error.
    *   **Main Protected Move:** Executes the primary protected move using `G53 G38.3 K{param.I} F{sensors.probes[param.I].travelSpeed} X{tPX} Y{tPY} Z{tPZ}`. This command moves towards the target, stopping immediately if the probe `I` is triggered.
    *   Retrieves the final machine position (`M5000 P0`) after the move.
    *   **Position Verification:** It compares the final machine position with the intended target position, allowing for a small `tolerance` (considering machine backlash). If the machine's final position deviates significantly from the target, it aborts with an error, indicating a potential collision or missed move.

### G6600: PROBE WORK PIECE

*   **Code:** `G6600`
*   **Description:** This is a comprehensive meta-macro that guides the user through the entire process of probing a workpiece. It prompts the user to select a Work Coordinate System (WCS) and then offers various probing operations (e.g., Vise Corner, Circular Bore, Rectangle Block) to establish the WCS origin.
*   **Arguments:**
    *   `W<work-offset>`: (Optional) The 0-indexed work offset number to use. If `null`, the macro will prompt the user to select a WCS.
*   **How it works:**
    *   Checks if the spindle is currently running and, if so, stops and parks it (`G27 Z1`) as a safety measure.
    *   Verifies that MillenniumOS is loaded (`global.mosLdd`).
    *   If the `W` parameter is `null`, it prompts the user to select a WCS from a list (`workOffsetCodes`) using `M291`.
    *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[0]`), it displays a series of `M291` dialogs explaining workpiece probing, different probe types, and cautions.
    *   If a WCS origin is already set, it prompts the user to "Continue", "Modify", or "Reset" the existing origin. If "Reset" is chosen, it clears the WCS origin (`G10 L2 P{wcsNumber} X0 Y0 Z0`) and resets all associated probe details (`M5010`).
    *   Switches to the probe tool (`global.mosPTID`) using `T T{global.mosPTID}`.
    *   Prompts the user to select a probing operation type (e.g., "Vise Corner", "Circular Bore") from `probeCycleNames` using `M291`.
    *   Cancels rotation compensation (`G69`).
    *   Resets probe counts (`M5012`).
    *   Calls the appropriate underlying G-code macro based on the user's selection (e.g., `G6520`, `G6500`, `G6501`, etc.), passing the selected `workOffset`.
    *   After the chosen probe cycle completes, it checks if all axes (X, Y, Z) in the selected WCS have been probed. If not, it prompts the user to run another probe cycle (making a recursive call to `G6600`).
    *   If all axes are probed, it prompts the user to "Continue" or "Re-Probe".
    *   Saves the current machine settings to a restore point using `M500.1`.
    *   Echoes a confirmation message that WCS origins have been saved.

### G73: DRILL CANNED CYCLE - PECK DRILLING WITH PARTIAL RETRACT

*   **Code:** `G73`
*   **Description:** Implements a peck drilling canned cycle with partial retract. In this cycle, the drill pecks into the material, retracts a small amount (partial retract) to clear chips, and then continues drilling. This is suitable for deep holes to prevent chip packing.
*   **Arguments:**
    *   `F<feedrate>`: The feed rate (mm/min) for the drilling operation.
    *   `R<retraction-plane>`: The Z-height (absolute) to which the drill retracts between pecks.
    *   `Q<peck-depth>`: The depth, in millimeters, of each peck.
    *   `Z<final-z-position>`: The final absolute Z-depth of the hole.
    *   `X<x-position>`: (Optional) The X-coordinate of the hole position.
    *   `Y<y-position>`: (Optional) The Y-coordinate of the hole position.
*   **How it works:**
    *   If `global.mosCCD` (MillenniumOS Canned Cycle Data) is `null` (indicating a new canned cycle), it validates that `F`, `R`, `Q`, and `Z` parameters are provided.
    *   Aborts if the spindle is off.
    *   Defaults `tZ`, `tF`, `tR`, `tQ` from the provided parameters or from `global.mosCCD` if the cycle is being repeated.
    *   Saves these values to `global.mosCCD` to allow for repetition of the cycle.
    *   Moves the Z-axis to the `retraction-plane` (`G0 Z{tR}`).
    *   If `X` or `Y` parameters are provided, it moves the machine to the specified hole position (`G0 X{X} Y{Y}`).
    *   Calculates `rR` (retract amount) which defaults to the tool radius or `tQ` if tool radius is not available.
    *   Enters a `while` loop that continues as long as the current peck position (`nZ`) is above the `final-z-position`:
        *   Feeds down to the current peck position (`G1 Z{nZ} F{tF}`).
        *   Retracts by `rR` (`G0 Z{nZ + rR}`).
        *   Updates `nZ` for the next peck`.
    *   After the loop, it feeds down to the `final-z-position` (`G1 Z{tZ} F{tF}`).
    *   Finally, it retracts the Z-axis to the `retraction-plane` (`G0 Z{tR}`).

### G80: CANNED CYCLE CANCEL

*   **Code:** `G80`
*   **Description:** Resets the internal state of any active canned drilling cycle. This prevents unintended repetition of canned cycle parameters in subsequent drilling operations.
*   **Arguments:** None.
*   **How it works:**
    *   Sets the `global.mosCCD` (MillenniumOS Canned Cycle Data) variable to `null`, effectively clearing any stored canned cycle parameters.

### G8000: MOS CONFIGURATION WIZARD

*   **Code:** `G8000`
*   **Description:** This comprehensive wizard guides the user through the initial setup and configuration of MillenniumOS. It is automatically triggered when MillenniumOS is first loaded if the `mos-user-vars.g` file is missing. It can also be run manually to reconfigure settings.
*   **Arguments:** None.
*   **How it works:**
    *   Displays a welcome message and initial prompts.
    *   **Resume/Reset Logic:** If MillenniumOS is already loaded or a startup error occurred, it prompts the user to "Continue" (to reconfigure specific features) or "Reset" (to start fresh). If a temporary resume file (`mos-resume-vars.g`) exists from a previous incomplete run, it offers to load those settings.
    *   **Mode Configuration:** Prompts the user to enable/disable `Tutorial Mode` (`global.mosTM`) and `Expert Mode` (`global.mosEM`). These settings are saved to the temporary resume file.
    *   **Feature Reconfiguration Prompts:** If not performing a full reset, it asks the user if they want to reconfigure Spindle, Coolant Control, Datum Tool, Toolsetter, and Touch Probe features individually.
    *   **Variable Initialization:** Initializes various `wiz` variables (e.g., `wizSpindleID`, `wizSpindleAccelSec`, `wizCoolantAirPinID`, `wizDatumToolRadius`, `wizToolSetterID`, `wizTouchProbeID`, `wizProtectedMoveBackOff`) either from existing `global.mos` values or as `null` if a reset is requested or the value is not yet set.
    *   **Spindle Configuration:**
        *   If `wizSpindleID` is `null`, it iterates through configured RRF spindles and prompts the user to select one.
        *   Prompts to enable `Spindle Feedback` (`wizFeatureSpindleFeedback`).
        *   If spindle acceleration/deceleration times (`wizSpindleAccelSec`, `wizSpindleDecelSec`) are `null`, it guides the user through a process of starting and stopping the spindle to measure these times.
        *   If `Spindle Feedback` is enabled, it uses `M8003` to detect GPIN changes during acceleration/deceleration and prompts the user to assign `wizSpindleChangePinID` and `wizSpindleStopPinID`.
        *   All spindle-related settings are written to the resume file.
    *   **Coolant Control Configuration:**
        *   Prompts to enable `Coolant Control` (`wizFeatureCoolantControl`).
        *   If enabled, it iterates through configured RRF general-purpose outputs, activates each one, and prompts the user to assign it to "Air", "Mist", "Flood", or "None" for `wizCoolantAirPinID`, `wizCoolantMistPinID`, `wizCoolantFloodPinID`.
        *   Coolant settings are written to the resume file.
    *   **Datum Tool Configuration:**
        *   If `wizDatumToolRadius` is `null`, it prompts the user to enter the radius of their chosen datum tool.
        *   The radius is written to the resume file.
    *   **Toolsetter and Touch Probe Feature Enable/Disable:**
        *   Prompts to enable `Toolsetter` (`wizFeatureToolSetter`) and `Touch Probe` (`wizFeatureTouchProbe`).
        *   These feature settings are written to the resume file.
    *   **Protected Move Back-Off:**
        *   If `wizProtectedMoveBackOff` is `null` and either toolsetter or touch probe is enabled, it prompts for the back-off distance for protected moves.
        *   The back-off distance is written to the resume file.
    *   **Toolsetter Configuration:**
        *   If `Toolsetter` is enabled and `wizToolSetterID` is `null`, it guides the user to activate their toolsetter to detect its ID using `M8001`.
        *   If `wizToolSetterRadius` is `null`, it prompts for the toolsetter radius.
        *   If `wizToolSetterPos` or `wizToolSetterZPos` are `null`, it guides the user through homing (if needed), installing the datum tool, jogging to the toolsetter center, and probing the toolsetter height using `G6512`.
        *   If `Touch Probe` is enabled and the reference surface needs measuring, it guides the user through probing a reference surface with the datum tool using `G6510.1`.
        *   All toolsetter-related settings are written to the resume file.
        *   Prompts the user to remove the datum tool.
    *   **Touch Probe Configuration:**
        *   If `Touch Probe` is enabled and `wizTouchProbeID`, `wizTouchProbeDeflection`, or `wizTouchProbeRadius` are `null`, it guides the user to activate their touch probe to detect its ID using `M8001`.
        *   If `wizTouchProbeRadius` is `null`, it prompts for the touch probe radius.
        *   If `wizTouchProbeDeflection` is `null`, it guides the user through homing (if needed), installing the touch probe, securing a rectangular item (e.g., 1-2-3 block), prompting for its dimensions, jogging to its center, and probing its surfaces using `G6503.1` to calculate X and Y deflection values.
        *   All touch probe-related settings are written to the resume file.
        *   Prompts the user to remove the touch probe.
    *   **Final Save:** All collected configuration settings are written to the permanent `mos-user-vars.g` file.
    *   The temporary resume file (`mos-resume-vars.g`) is deleted.
    *   Finally, it prompts the user to reload MillenniumOS (`M9999`) or reboot the mainboard (`M999`).

### G81: DRILL CANNED CYCLE - FULL DEPTH

*   **Code:** `G81`
*   **Description:** Implements a basic drill canned cycle that drills a hole to its full specified depth in a single pass, then retracts to a safe plane.
*   **Arguments:**
    *   `F<feedrate>`: The feed rate (mm/min) for the drilling operation.
    *   `R<retraction-plane>`: The Z-height (absolute) to which the drill retracts after completing the hole.
    *   `Z<final-z-position>`: The final absolute Z-depth of the hole.
    *   `X<x-position>`: (Optional) The X-coordinate of the hole position.
    *   `Y<y-position>`: (Optional) The Y-coordinate of the hole position.
*   **How it works:**
    *   If `global.mosCCD` (MillenniumOS Canned Cycle Data) is `null` (indicating a new canned cycle), it validates that `F`, `R`, and `Z` parameters are provided.
    *   Aborts if the spindle is off.
    *   Defaults `tZ`, `tF`, `tR` from the provided parameters or from `global.mosCCD` if the cycle is being repeated.
    *   Saves these values to `global.mosCCD` to allow for repetition of the cycle.
    *   Moves the Z-axis to the `retraction-plane` (`G0 Z{tR}`).
    *   If `X` or `Y` parameters are provided, it moves the machine to the specified hole position (`G0 X{X} Y{Y}`).
    *   Feeds down to the `final-z-position` (`G1 Z{tZ} F{tF}`).
    *   Retracts the Z-axis to the `retraction-plane` (`G0 Z{tR}`).

### G83: DRILL CANNED CYCLE - PECK DRILLING WITH FULL RETRACT

*   **Code:** `G83`
*   **Description:** Implements a peck drilling canned cycle with full retract. In this cycle, the drill pecks into the material, fully retracts to the safe retraction plane to clear chips, and then continues drilling. This is suitable for very deep holes or materials that produce long chips.
*   **Arguments:**
    *   `F<feedrate>`: The feed rate (mm/min) for the drilling operation.
    *   `R<retraction-plane>`: The Z-height (absolute) to which the drill fully retracts between pecks.
    *   `Q<peck-depth>`: The depth, in millimeters, of each peck.
    *   `Z<final-z-position>`: The final absolute Z-depth of the hole.
    *   `X<x-position>`: (Optional) The X-coordinate of the hole position.
    *   `Y<y-position>`: (Optional) The Y-coordinate of the hole position.
*   **How it works:**
    *   If `global.mosCCD` (MillenniumOS Canned Cycle Data) is `null` (indicating a new canned cycle), it validates that `F`, `R`, `Q`, and `Z` parameters are provided.
    *   Aborts if the spindle is off.
    *   Defaults `tZ`, `tF`, `tR`, `tQ` from the provided parameters or from `global.mosCCD` if the cycle is being repeated.
    *   Saves these values to `global.mosCCD` to allow for repetition of the cycle.
    *   Moves the Z-axis to the `retraction-plane` (`G0 Z{tR}`).
    *   If `X` or `Y` parameters are provided, it moves the machine to the specified hole position (`G0 X{X} Y{Y}`).
    *   Enters a `while` loop that continues as long as the current peck position (`nZ`) is above the `final-z-position`:
        *   Feeds down to the current peck position (`G1 Z{nZ} F{tF}`).
        *   Fully retracts the Z-axis to the `retraction-plane` (`G0 Z{tR}`).
        *   Updates `nZ` for the next peck`.
    *   After the loop, it feeds down to the `final-z-position` (`G1 Z{tZ} F{tF}`).
    *   Finally, it retracts the Z-axis to the `retraction-plane` (`G0 Z{tR}`).

---

## Private Macros (`macro/private/`)

### display-startup-messages.g: DISPLAY STARTUP MESSAGES

*   **Code:** (Internal macro, not a G/M code)
*   **Description:** This macro is responsible for displaying important startup messages in the Duet Web Control (DWC) interface the first time it's accessed after a mainboard reboot. If MillenniumOS fails to load during startup, it will prompt the user to run the configuration wizard.
*   **Arguments:** None.
*   **How it works:**
    *   Checks `global.mosStartupMsgsDisplayed`. If `false`, it sets it to `true` to ensure messages are only shown once per session.
    *   If MillenniumOS is not loaded (`!global.mosLdd`):
        *   If `0:/sys/mos-user-vars.g` (the user configuration file) does not exist, it echoes a message indicating that no user configuration was found and prompts to run `G8000`.
        *   Otherwise, it displays a startup error message (either from `global.mosErr` or a generic "Unknown Startup Error") and uses `M291` to prompt the user to run `G8000` (the configuration wizard).
    *   If MillenniumOS is successfully loaded (`global.mosLdd` is `true`), it echoes the loaded MillenniumOS version (`global.mosVer`).

### run-vssc.g: IMPLEMENTS VARIABLE SPINDLE SPEED CONTROL

*   **Code:** (Internal macro, not a G/M code)
*   **Description:** This macro implements the core logic for Variable Spindle Speed Control (VSSC). Its purpose is to periodically vary the spindle speed by a user-configured amount around the target speed. This helps to prevent the generation of resonant frequencies during machining, which can improve surface finish and tool life. This script is executed repeatedly as part of the `daemon.g` loop.
*   **Arguments:** None.
*   **How it works:**
    *   Checks if MillenniumOS is loaded (`global.mosLdd`). If not, it exits.
    *   If the spindle is not active (not "forward" or "reverse") or its active speed is zero, the macro exits silently.
    *   Calculates `curTime` (current uptime in milliseconds) and `elapsedTime` since the last VSSC speed adjustment. It includes logic to handle time rollovers.
    *   Calculates a `lowerLimit` for the spindle speed adjustment, ensuring it stays within the spindle's minimum and maximum configured speeds and respects the VSSC variance.
    *   If the current spindle's active RPM is outside the calculated adjustment limits, it means the base RPM has changed. In this case, `global.mosVSPS` (VSSC base speed) is updated to the current spindle speed, and `global.mosVSPT` (VSSC adjustment time) is reset.
    *   Otherwise, it calculates an `adjustedSpindleRPM` using a sinusoidal function. This function varies the speed around the `lowerLimit` by `global.mosVSV` (VSSC variance) over `global.mosVSP` (VSSC period).
    *   If a tool is currently selected, it sets the adjusted spindle RPM using `M568 F{adjustedSpindleRPM}`.
    *   If `global.mosDebug` is enabled, it echoes debug information about the VSSC state and adjusted RPM.

---

## Public Macros (`macro/public/`)

These macros are typically simple wrappers that call the core G-code macros, often without additional parameters, to provide user-friendly access to common operations.

### 1. Probing/Probe Cycles/Bore Probe.g

*   **Code:** `G6500`
*   **Description:** Initiates the circular bore probing cycle.
*   **Arguments:** None.
*   **How it works:** Simply executes `G6500`.

### 1. Probing/Probe Cycles/Boss Probe.g

*   **Code:** `G6501`
*   **Description:** Initiates the circular boss probing cycle.
*   **Arguments:** None.
*   **How it works:** Simply executes `G6501`.

### 1. Probing/Probe Cycles/Outside Corner Probe.g

*   **Code:** `G6508`
*   **Description:** Initiates the outside corner probing cycle.
*   **Arguments:** None.
*   **How it works:** Simply executes `G6508`.

### 1. Probing/Probe Cycles/Rectangle Block Probe.g

*   **Code:** `G6503`
*   **Description:** Initiates the rectangular block probing cycle.
*   **Arguments:** None.
*   **How it works:** Simply executes `G6503`.

### 1. Probing/Probe Cycles/Single Surface Probe.g

*   **Code:** `G6510`
*   **Description:** Initiates the single surface probing cycle.
*   **Arguments:** None.
*   **How it works:** Simply executes `G6510`.

### 1. Probing/Probe Cycles/Vise Corner Probe.g

*   **Code:** `G6520`
*   **Description:** Initiates the vise corner probing cycle.
*   **Arguments:** None.
*   **How it works:** Simply executes `G6520`.

### 1. Probing/Probe Workpiece.g

*   **Code:** `G6600 W{null}`
*   **Description:** Prompts the operator to select a Work Coordinate System (WCS) and then guides them through a workpiece probing cycle.
*   **Arguments:** None (internally passes `W{null}` to `G6600` to trigger WCS selection).
*   **How it works:** Calls `G6600` with a `null` `W` parameter, which causes `G6600` to prompt the user for the target WCS.

### 2. Movement/Disable Rotation Compensation.g

*   **Code:** `G69`
*   **Description:** Disables any active rotation compensation.
*   **Arguments:** None.
*   **How it works:** Executes `G69` and echoes a confirmation message to the console.

### 2. Movement/Enable Rotation Compensation.g

*   **Code:** `M5011`
*   **Description:** Calls `M5011` to enable rotation compensation based on previously probed workpiece rotation.
*   **Arguments:** None.
*   **How it works:** Simply executes `M5011`.

### 2. Movement/Park.g

*   **Code:** `G27`
*   **Description:** Calls `G27` to park the machine's spindle and work area.
*   **Arguments:** None.
*   **How it works:** Simply executes `G27`.

### 3. Config/Run Configuration Wizard.g

*   **Code:** `G8000`
*   **Description:** Calls `G8000` to launch the MillenniumOS configuration wizard.
*   **Arguments:** None.
*   **How it works:** Simply executes `G8000`.

### 3. Config/Settings/Toggle Daemon Tasks.g

*   **Code:** (No direct G/M code, modifies `global.mosDAE`)
*   **Description:** Toggles the enabled/disabled state of MillenniumOS daemon tasks.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled, it prompts the user for confirmation before toggling.
    *   Toggles the boolean value of `global.mosDAE`.
    *   Echoes the new state of daemon tasks to the console.

### 3. Config/Settings/Toggle Debug Mode.g

*   **Code:** (No direct G/M code, modifies `global.mosDebug`)
*   **Description:** Toggles MillenniumOS debug mode, which enables or disables verbose output to the console for debugging purposes.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosDebug` is currently `false`, it prompts the user for confirmation about enabling verbose output.
    *   Toggles the boolean value of `global.mosDebug`.
    *   Echoes the new state of debug mode to the console.

### 3. Config/Settings/Toggle Expert Mode.g

*   **Code:** (No direct G/M code, modifies `global.mosEM`)
*   **Description:** Toggles MillenniumOS expert mode. When enabled, this mode disables some confirmation prompts and probing descriptions to reduce operator interaction.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled, it prompts the user for confirmation before toggling, explaining the implications of expert mode.
    *   Toggles the boolean value of `global.mosEM`.
    *   Echoes the new state of expert mode to the console.

### 3. Config/Settings/Toggle Spindle Feedback.g

*   **Code:** (No direct G/M code, modifies `global.mosFeatSpindleFeedback`)
*   **Description:** Toggles the Spindle Feedback feature. This feature allows MillenniumOS to use sensor input to detect when the spindle has reached target speed or stopped.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosFeatSpindleFeedback` is currently enabled, it prompts the user for confirmation before disabling it.
    *   Checks if spindle feedback pins (`global.mosSFCID`, `global.mosSFSID`) are configured. If not, it displays a message and exits, requiring the user to run the Configuration Wizard first.
    *   Toggles the boolean value of `global.mosFeatSpindleFeedback`.
    *   Echoes the new state of the Spindle Feedback feature to the console.

### 3. Config/Settings/Toggle Toolsetter.g

*   **Code:** (No direct G/M code, modifies `global.mosFeatToolSetter`)
*   **Description:** Toggles the Toolsetter feature. When enabled, MillenniumOS can use a toolsetter for automated tool length measurement and offset calculation.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosFeatToolSetter` is currently enabled, it prompts the user for confirmation before disabling it, warning about manual Z origin resets.
    *   Checks if toolsetter ID and position (`global.mosTSID`, `global.mosTSP`) are configured. If not, it displays a message and exits, requiring the user to run the Configuration Wizard first.
    *   Toggles the boolean value of `global.mosFeatToolSetter`.
    *   Echoes the new state of the Toolsetter feature to the console.

### 3. Config/Settings/Toggle Touch Probe.g

*   **Code:** (No direct G/M code, modifies `global.mosFeatTouchProbe`)
*   **Description:** Toggles the Touch Probe feature. This feature enables MillenniumOS to use a touch probe for workpiece probing operations. When enabled, the probe tool is configured as a "Touch Probe"; when disabled, it reverts to a "Datum Tool" for manual probing.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosFeatTouchProbe` is currently enabled, it prompts the user for confirmation before disabling it, explaining the fallback to manual probing.
    *   Checks if touch probe ID, reference position, radius, and deflection (`global.mosTPID`, `global.mosTPRP`, `global.mosTPR`, `global.mosTPD`) are configured. If not, it displays a message and exits, requiring the user to run the Configuration Wizard first.
    *   Toggles the boolean value of `global.mosFeatTouchProbe`.
    *   If enabling the feature, it defines the probe tool (`global.mosPTID`) as "Touch Probe" with its configured radius using `M4000`.
    *   If disabling the feature, it resets `global.mosTSAP` to `null` and defines the probe tool as "Datum Tool" with `global.mosDTR` (datum tool radius) using `M4000`.
    *   Echoes the new state of the Touch Probe feature to the console.

### 3. Config/Settings/Toggle Tutorial Mode.g

*   **Code:** (No direct G/M code, modifies `global.mosTM`)
*   **Description:** Toggles MillenniumOS tutorial mode. When enabled, this mode provides detailed guides for configuration and probing cycles, along with additional confirmation points during operations.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosTM` is currently `false`, it prompts the user for confirmation before enabling it.
    *   Toggles the boolean value of `global.mosTM`.
    *   Echoes the new state of tutorial mode to the console.

### 3. Config/Settings/Toggle VSSC.g

*   **Code:** (No direct G/M code, modifies `global.mosVSOE`)
*   **Description:** Toggles the Variable Spindle Speed Control (VSSC) override behavior. This allows the operator to temporarily enable or disable VSSC on the fly, even if it's configured to be active.
*   **Arguments:** None.
*   **How it works:**
    *   If `global.mosTM` (tutorial mode) is enabled, it prompts the user for confirmation before toggling.
    *   Toggles the boolean value of `global.mosVSOE`.
    *   If VSSC override is disabled (`!global.mosVSOE`) but VSSC was enabled (`global.mosVSEnabled`), it resets the spindle speed to the last recorded base speed (`global.mosVSPS`) using `M568`.
    *   Resets `global.mosVSPT` (VSSC adjustment time) and `global.mosVSPS` (VSSC base speed) to 0.
    *   Echoes the new state of VSSC override to the console.

### 4. Misc/Print All Variables.g

*   **Code:** `M7600`
*   **Description:** Calls `M7600` to output all MillenniumOS global variables to the console.
*   **Arguments:** None.
*   **How it works:** Simply executes `M7600`.

### 4. Misc/Reload.g

*   **Code:** `M9999`
*   **Description:** Calls `M9999` to reload MillenniumOS.
*   **Arguments:** None.
*   **How it works:**
    *   If not in expert mode (`!global.mosEM`), it prompts the user for confirmation before reloading.
    *   Executes `M9999`.

### 4. Misc/Restore Point/Discard Restore Point.g

*   **Code:** `M501.1 D1`
*   **Description:** Calls `M501.1` with the `D1` parameter to discard the saved restore point file without prompting the user.
*   **Arguments:** None.
*   **How it works:** Simply executes `M501.1 D1`.

### 4. Misc/Restore Point/Load Restore Point.g

*   **Code:** `M501.1`
*   **Description:** Calls `M501.1` to load previously saved machine settings (WCS origins, tool data) from the restore point file.
*   **Arguments:** None.
*   **How it works:** Simply executes `M501.1`.

### 4. Misc/Restore Point/Save Restore Point.g

*   **Code:** `M500.1`
*   **Description:** Calls `M500.1` to save the current machine settings (WCS origins, tool data) to a restore point file.
*   **Arguments:** None.
*   **How it works:** Simply executes `M500.1`.

### 4. Misc/Safety Net/Disable Machine Power.g

*   **Code:** `M81.9`
*   **Description:** Calls `M81.9` to prompt the operator to disable ATX power, if configured.
*   **Arguments:** None.
*   **How it works:** Simply executes `M81.9`.

### 4. Misc/Safety Net/Enable Machine Power.g

*   **Code:** `M80.9`
*   **Description:** Calls `M80.9` to prompt the operator to enable ATX power, if configured.
*   **Arguments:** None.
*   **How it works:** Simply executes `M80.9`.

---

## Tool Change Macros (`macro/tool-change/`)

### tfree.g: FREE CURRENT TOOL

*   **Code:** (Internal tool change macro, executed by RRF)
*   **Description:** This macro is executed by RepRapFirmware (RRF) before a tool is "freed" (unloaded). If the current tool is a touch probe or datum tool, it prompts the operator to safely remove and stow it.
*   **Arguments:** None.
*   **How it works:**
    *   Sets `global.mosTCS` (MillenniumOS Tool Change State) to 0.
    *   Aborts if any of the X, Y, or Z axes are not homed.
    *   Stops and parks the spindle using `G27 Z1`.
    *   If the `state.currentTool` matches `global.mosPTID` (the probe tool ID), it displays an `M291` dialog prompting the operator to remove either the "Touch Probe" or "Datum Tool" (depending on `global.mosFeatTouchProbe`) and confirm when it's safely stowed.
    *   Sets `global.mosTCS` to 1 to indicate that `tfree.g` has completed its initial steps.

### tpost.g: POST TOOL CHANGE - EXECUTE

*   **Code:** (Internal tool change macro, executed by RRF)
*   **Description:** This macro is executed by RepRapFirmware (RRF) after a tool change has physically occurred. It is responsible for post-tool-change operations such as probing the new tool's length or probing a reference surface if a touch probe is installed.
*   **Arguments:** None.
*   **How it works:**
    *   Aborts if no tool is selected (`state.currentTool < 0`) or if the machine is not homed.
    *   Aborts if `tpre.g` (pre-tool change macro) did not run to completion (`global.mosTCS < 3`), ensuring a consistent tool change state.
    *   Sets `global.mosTCS` to 4.
    *   Stops and parks the spindle using `G27 Z1`.
    *   **Probe Tool Handling:** If the `state.currentTool` is `global.mosPTID` (the probe tool):
        *   If both `global.mosFeatTouchProbe` and `global.mosFeatToolSetter` are enabled, it prompts the user via `M291` and then calls `G6511` (reference surface probe) in non-standalone mode (`S0`) and forces a re-probe (`R1`). It aborts if the reference surface probe fails.
        *   If only `global.mosFeatToolSetter` is enabled, it prompts the user and then calls `G37` (tool length probe) to probe the datum tool's length.
    *   **Other Tool Handling:** If the current tool is *not* the probe tool:
        *   If `global.mosFeatToolSetter` is enabled, it calls `G37` to probe the tool's length using the toolsetter.
        *   Otherwise (no toolsetter), it calls `G37.1` to guide the operator through manually probing the Z origin with the installed tool.
    *   Sets `global.mosTCS` to `null` to indicate the tool change process is complete.

### tpre.g: PRE TOOL CHANGE - EXECUTE

*   **Code:** (Internal tool change macro, executed by RRF)
*   **Description:** This macro is executed by RepRapFirmware (RRF) before a tool change operation begins. It provides guidance to the operator, handles safety checks, and manages the state for the tool change process.
*   **Arguments:** None.
*   **How it works:**
    *   Aborts if no next tool is selected (`state.nextTool < 0`).
    *   Aborts if `tfree.g` (free current tool macro) did not run to completion (`global.mosTCS < 1`), ensuring a consistent tool change state.
    *   Sets `global.mosTCS` (MillenniumOS Tool Change State) to 2.
    *   Aborts if any of the X, Y, or Z axes are not homed.
    *   Stops and parks the spindle using `G27 Z1`.
    *   **Probe Tool Preparation:** If the `state.nextTool` is `global.mosPTID` (the probe tool):
        *   If `global.mosFeatTouchProbe` is enabled, it prompts the user via `M291` to install the touch probe and then waits for its activation using `M8002`. It aborts if the probe is not detected.
        *   Otherwise (touch probe disabled), it prompts the user to install the datum tool.
    *   **Other Tool Preparation:** If the `state.nextTool` is *not* the probe tool:
        *   If both `global.mosFeatTouchProbe` and `global.mosFeatToolSetter` are enabled, but `global.mosTSAP` (reference surface activation point) is `null`, it aborts and instructs the user to run `G6511` first.
        *   If `global.mosTM` (tutorial mode) is enabled and the specific tutorial message hasn't been displayed (`global.mosDD[13]`), it displays `M291` dialogs explaining the tool change process, including radius offset probing if applicable.
        *   It prompts the user via `M291` to insert the correct tool and confirm when ready. It aborts if the user cancels.
    *   Sets `global.mosTCS` to 3 to indicate that `tpre.g` has completed.

---

## High-Level Post-Processor Interaction and Start of Job Sequence

When a post-processor generates G-code for MillenniumOS, it typically orchestrates a sequence of custom G and M codes to prepare the machine and workpiece for machining. This ensures a safe, consistent, and automated workflow.

Here's a common high-level sequence of operations a post-processor would generate at the start of a job:

1.  **MillenniumOS Version Check (`M4005`):**
    *   The very first command is usually `M4005 V<post-processor-version>`. This is a critical compatibility check. If the post-processor's version doesn't match the installed MillenniumOS version, the job will immediately abort. This prevents unexpected behavior due to API changes or feature differences between versions.

2.  **Tool Definitions (`M4000`):**
    *   Before any tools are used, the post-processor will define them using `M4000 P<tool-number> R<radius> S"<description>" [X<deflection-x>] [Y<deflection-y>]`.
    *   This command registers each tool with MillenniumOS, storing essential data like its radius and, for probing tools, X/Y deflection values. This information is crucial for accurate probing and compensation later.

3.  **Initial Tool Selection (`T<tool-number>`):**
    *   The post-processor selects the first tool for the job (e.g., `T0`). This standard RRF command triggers MillenniumOS's internal tool change macros:
        *   **`tpre.g` (Pre-Tool Change):** This macro runs *before* the physical tool change. It parks the spindle (`G27 Z1`), prompts the operator to install the correct tool (or touch probe/datum tool), and performs checks (e.g., waiting for touch probe activation if `global.mosFeatTouchProbe` is enabled).
        *   **`tpost.g` (Post-Tool Change):** This macro runs *after* the physical tool change. It again parks the spindle (`G27 Z1`) and then handles tool length probing (`G37`) or Z-origin setting (`G37.1`) if a toolsetter is present or required. If a touch probe is installed, it might also trigger `G6511` to probe the reference surface.

4.  **Workpiece Probing (`G6600` or specific `G65xx` macros):**
    *   Once the initial tool is set up, the workpiece's position and orientation need to be established.
    *   **Interactive Probing:** For operator-guided setup, the post-processor might call `G6600 [W<work-offset>]`. This launches the interactive workpiece probing wizard, allowing the operator to select the WCS and the appropriate probing cycle (e.g., Vise Corner, Circular Bore) via `M291` dialogs.
    *   **Automated Probing:** For fully automated workflows, the post-processor could directly call specific probing macros like `G6520.1` (Vise Corner - Execute), `G6500.1` (Bore - Execute), `G6503.1` (Rectangle Block - Execute), etc., with pre-defined parameters. This bypasses the interactive prompts.

5.  **Rotation Compensation (`M5011` or `G69`):**
    *   If a probing cycle has determined that the workpiece is rotated relative to the machine axes, `M5011` might be called. This macro applies the necessary rotation compensation (`G68`) to the active WCS, ensuring subsequent toolpaths are correctly aligned.
    *   If no rotation is expected or desired, `G69` might be explicitly called to cancel any previously active rotation compensation.

6.  **Spindle Activation (`M3.9`, `M4.9`):**
    *   When the first cutting operation is about to begin, the spindle is activated. The post-processor will use `M3.9 S<rpm> [P<spindle-id>]` for clockwise rotation or `M4.9 S<rpm> [P<spindle-id>]` for counter-clockwise rotation. These custom M-codes ensure that the spindle accelerates to the target speed and waits for a safe dwell time before proceeding.

7.  **Coolant Activation (`M7`, `M7.1`, `M8`):**
    *   If coolant is required for the machining operation, the post-processor will issue the appropriate custom M-codes:
        *   `M7.1`: Activates air blast.
        *   `M7`: Activates mist coolant (air + unpressurized coolant).
        *   `M8`: Activates flood coolant (pressurized coolant).

This structured approach ensures that the machine is in a known, safe, and correctly configured state before any material removal begins.