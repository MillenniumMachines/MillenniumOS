# NeXT Tool Setting and Offsetting Workflow

This document outlines the complete tool setting and Z-offsetting workflow for NeXT. It combines a **Static Datum** (calibrated once) for machine geometry with a **Relative Offsetting** (with caching) approach for tool changes to ensure accuracy, efficiency, and ease of use.

---

## 1. Core Principles

- **Static Datum:** The physical Z-distance between the toolsetter's activation plane and a designated reference surface is measured once during setup and stored permanently as `nxtDeltaMachine`. This provides a stable, geometric foundation for all Z-height calculations.
- **Relative Offsetting:** All tool-to-tool offset calculations are *relative*. The system calculates the difference in measured length between the old tool and the new tool and applies that difference to the running tool offset.
- **Session Caching:** To improve efficiency, the measured Z-activation point of a tool is cached for the duration of a power-on session. This avoids redundant measurements during subsequent tool changes.
- **Explicit Workflows:** The system handles common scenarios (probe-to-cutter, cutter-to-cutter) automatically and provides a safe, explicit path for edge cases like starting with an unmeasured tool.

---

## 2. Phase 1: One-Time Static Datum Calibration

This process is performed once via the UI-based configuration to establish the machine's core geometry. It is only re-run if the toolsetter or reference surface is physically moved.

1.  **Install Datum Tool:** The user installs a rigid, known-geometry datum tool (e.g., a gauge pin).
2.  **Measure Toolsetter:** The system automatically probes the toolsetter with the datum tool to get the absolute machine coordinate `Z_act_datum`.
3.  **Measure Reference Surface:** The user manually jogs the datum tool to the designated flat reference surface to get the absolute machine coordinate `Z_ref_datum`.
4.  **Store Static Datum:** The system calculates and permanently saves the static datum:
    `nxtDeltaMachine = Z_ref_datum - Z_act_datum`

### UI Babystepping

To account for minor physical changes or thermal drift over time, the UI will provide a "babystepping" function. This will allow the operator to apply small, persistent adjustments (e.g., +/- 0.01mm) to the stored `nxtDeltaMachine` value without needing to perform a full recalibration.

---

## 3. Phase 2: In-Job Tool & Origin Management

This section describes the workflows an operator will encounter during a typical job.

### Scenario A: Initial WCS Z-Origin Setup (with Touch Probe)

This is the standard and recommended way to start a job.

1.  The operator installs the **touch probe**.
2.  From the UI, they initiate a "Probe Z" cycle on the workpiece.
3.  The probe touches the workpiece, recording the trigger coordinate `Z_wcs_trigger`.
4.  The system sets the WCS Z-origin directly to this point (`G10 L20 P(wcs) Z{Z_wcs_trigger}`) and internally sets the probe's current tool offset to `0`.

*Result: The machine's coordinate system is now defined such that the tip of the triggered probe is at Z=0 in the active WCS.*

### Scenario B: First Tool Change (Probe -> Cutter)

This workflow uses the static datum to link the two different measurement devices (reference surface and toolsetter).

1.  A tool change from the probe to a cutting tool is commanded.
2.  **Measure "Old" Tool (Probe):** The system automatically probes the **reference surface** with the touch probe, recording `Z_ref_probe`.
3.  **Swap:** The user is prompted to swap the probe for the new cutting tool.
4.  **Measure "New" Tool (Cutter):** The system automatically probes the **toolsetter** with the new cutter, recording `Z_act_cutter`.
5.  **Calculate Offset:**
    - The probe's "virtual" position on the toolsetter is calculated: `Z_act_probe_virtual = Z_ref_probe - nxtDeltaMachine`.
    - The length difference is found: `Length_Diff = Z_act_cutter - Z_act_probe_virtual`.
    - The new tool's offset is the probe's offset (which was 0) plus the difference: `New_Offset = 0 + Length_Diff`.
6.  **Apply & Cache:** The system applies this `New_Offset` to the cutter (`G10 L1...`) and **caches** the measured `Z_act_cutter` value for this tool for the current session.

### Scenario C: Subsequent Tool Change (Cutter A -> Cutter B)

This workflow is optimized using the session cache.

1.  A tool change from Cutter A to Cutter B is commanded.
2.  **Use Cached Value for "Old" Tool:** The system retrieves the cached `Z_act_cutter_A` from when Cutter A was installed. **No measurement is performed.**
3.  **Swap:** The user is prompted to swap Cutter A for Cutter B.
4.  **Measure "New" Tool (Cutter B):** The system measures Cutter B on the **toolsetter**, recording `Z_act_cutter_B`.
5.  **Calculate Offset:**
    - The length difference is a direct comparison: `Length_Diff = Z_act_cutter_B - Z_act_cutter_A`.
    - The new offset is calculated relative to the previous one: `New_Offset = Old_Offset_A + Length_Diff`.
6.  **Apply & Cache:** The system applies the `New_Offset` to Cutter B and **caches** the `Z_act_cutter_B` value.

### Scenario D: The `T-1` Edge Case (Unmeasured Tool -> Known Tool)

This workflow handles the situation where an operator sets an origin with an unmeasured tool.

1.  **Initial State:** The machine is in `T-1` (no tool selected). The operator has installed a tool and manually set a WCS Z-origin (e.g., by touching off on paper and sending `G10 L20 P(wcs) Z0`). The system has no length data for this tool.
2.  **Tool Change Request:** The operator commands a change to a known tool (e.g., `T0`) or the touch probe.
3.  **System Action:** The system cannot automatically determine a valid offset because the reference length is unknown. Instead of guessing, it will take the safest path:
    - It will invalidate the current Z-origin by displaying a clear message to the operator.
    - It will **force the user to manually re-establish the Z-origin** with the new tool.
    - If the new tool is a cutter, it will prompt the user to perform a manual touch-off.
    - If the new tool is the touch probe, it will prompt the user to run the standard "Probe Z" cycle (Scenario A).

This approach ensures that there is no ambiguity. It prioritizes safety and accuracy by refusing to perform an offset calculation without a known reference, guiding the user to the correct, safe procedure.