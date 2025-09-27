# Legacy MillenniumOS UI Functionality Documentation

This document outlines the functionality of the MillenniumOS User Interface (UI) components, describing their purpose, how they work, and the features they enable.

---

## Core Plugin Files

### `plugin.json`
*   **Purpose:** Manifest file for the Duet Web Control (DWC) plugin.
*   **Key Functionality:** Defines plugin metadata (ID, name, author, version, license, homepage), DWC/RRF compatibility, and the webpack chunk name (`dwcWebpackChunk`) for the plugin's UI assets.
*   **How it works:** This JSON file is read by DWC to register and load the MillenniumOS plugin, providing essential information about it.
*   **Enabled Features:** Enables DWC to recognize, load, and display the MillenniumOS plugin.

### `ui/src/index.ts`
*   **Purpose:** The main entry point for the MillenniumOS UI plugin.
*   **Key Functionality:**
    *   Registers plugin localization (`en.json`).
    *   Registers a new route in DWC under "Control -> MillenniumOS", making the plugin's main interface accessible.
    *   Registers plugin-specific data (`protectedMoveProbeID`) in the machine cache for persistent state storage.
    *   Imports and implicitly registers various UI components (inputs, panels, overrides) for use throughout the plugin.
*   **How it works:** This TypeScript file is compiled and executed by DWC when the plugin loads. It uses DWC's plugin API (`registerRoute`, `registerPluginLocalization`, `registerPluginData`) to integrate MillenniumOS into the DWC environment.
*   **Enabled Features:** Integrates the MillenniumOS UI into DWC, provides localization, and sets up initial global state for the UI.

### `ui/src/MillenniumOS.vue`
*   **Purpose:** The main layout component for the MillenniumOS plugin's custom dashboard view.
*   **Key Functionality:** Structures the primary display area for MillenniumOS, arranging various sub-panels.
*   **How it works:** This Vue component acts as a container, using other custom components like `<mos-probing-panel>` and `<mos-workplace-origins-panel>` to build its layout. It uses Vuetify's grid system (`v-row`, `v-col`) for responsive design.
*   **Enabled Features:** Provides the overarching visual structure for the MillenniumOS dashboard, bringing together key functional panels.

---

## Base Components

### `ui/src/components/BaseComponent.vue`
*   **Purpose:** A foundational Vue component that provides common computed properties and methods for other MillenniumOS UI components.
*   **Key Functionality:**
    *   `uiFrozen`: Indicates if the UI is temporarily frozen (e.g., during macro execution).
    *   `allAxesHomed`: Checks if all visible axes are homed.
    *   `visibleAxesByLetter`: Provides a mapping of visible axes by their letter (X, Y, Z).
    *   `currentTool`: Retrieves the currently selected tool from the machine model.
    *   `probeTool`: Retrieves the configured probe tool based on `global.mosPTID`.
    *   `currentWorkplace`: Gets and sets the current active Work Coordinate System (WCS) number, sending a G-code command to change it.
    *   `absolutePosition`: Calculates the absolute machine position for visible axes, considering workplace offsets.
    *   `sendCode(code: string)`: A method to send G-code commands to the machine via the DWC store.
*   **How it works:** It leverages Vue's `computed` properties to reactively access and process data from the Vuex store (`@/store`), which mirrors the Duet3D Object Model. The `sendCode` method dispatches an action to the store to send G-code. Other components `extends` this base component to inherit this common logic.
*   **Enabled Features:** Centralizes common UI logic, reducing code duplication and ensuring consistent interaction with machine state and commands across the MillenniumOS UI.

---

## Input Components (`ui/src/components/inputs/`)

### `ui/src/components/inputs/index.ts`
*   **Purpose:** Registers all custom input components globally within the Vue application.
*   **Key Functionality:** Makes input components available for use in any Vue template by registering them with a custom tag (e.g., `mos-axis-input`).
*   **How it works:** Imports each input component (`.vue` file) and uses `Vue.component()` to register it globally.
*   **Enabled Features:** Streamlines the usage of custom input controls throughout the UI.

### `ui/src/components/inputs/AxisInput.vue`
*   **Purpose:** Provides a specialized input field for modifying individual axis workplace offsets within a WCS.
*   **Key Functionality:**
    *   Displays the current axis coordinate for a given workplace offset.
    *   Allows users to input a new coordinate value.
    *   Performs client-side validation to ensure the input is a valid number and within the axis's physical limits.
    *   Sends a `G10 L2 P<workplace-number> <axis-letter><value>` G-code command to update the workplace offset when the input changes.
    *   Provides visual feedback for loading states and displays error messages for invalid input.
*   **How it works:** Extends `BaseComponent.vue` to inherit `sendCode`. It uses a Vuetify `v-text-field` for input, binding its value to a computed property (`coord`) that handles formatting, validation, and updating a `pendingValue`. The `setCoordinate` method is triggered on input change to send the G-code command. A custom `v-visible` directive manages error tooltip visibility.
*   **Enabled Features:** Enables precise, validated, and direct adjustment of WCS axis offsets by the operator, improving accuracy and preventing out-of-bounds commands.

---

## Panel Components (`ui/src/components/panels/`)

### `ui/src/components/panels/index.ts`
*   **Purpose:** Registers all custom panel components globally within the Vue application.
*   **Key Functionality:** Makes panel components available for use in any Vue template by registering them with a custom tag (e.g., `mos-probing-panel`).
*   **How it works:** Imports each panel component (`.vue` file) and uses `Vue.component()` to register it globally.
*   **Enabled Features:** Organizes and makes available the various UI panels that display machine status, probing options, and other MillenniumOS-specific information.

### `ui/src/components/panels/CNCAxesPosition.vue`
*   **Purpose:** Displays the current position of the CNC axes in a visually clear and informative manner.
*   **Key Functionality:**
    *   Shows the letter (e.g., X, Y, Z) for each visible axis.
    *   Displays the tool position for each axis.
    *   Optionally displays the machine position for each axis.
    *   Provides visual cues (color-coded spans) to indicate the homing status of each axis (not homed, homed, at endstop).
    *   Offers tooltips with more detailed status information on hover.
*   **How it works:** Extends `BaseComponent.vue` to access machine state. It iterates over `visibleAxes` (from the store) and uses a global utility (`$displayAxisPosition`) to format position values. Methods like `axisState` and `axisSpanClasses` dynamically determine the visual representation based on axis status and theme.
*   **Enabled Features:** Provides operators with real-time, at-a-glance monitoring of machine axis positions and their operational status, crucial for safe and accurate machine control.

### `ui/src/components/panels/JobCodePanel.vue`
*   **Purpose:** To display G-code, typically the G-code that is currently being executed or is part of a job.
*   **Key Functionality:** Renders G-code within a `<code-stream>` component.
*   **How it works:** It's a simple card component that displays a G-code string. In its current form, the G-code is hardcoded, suggesting it serves as a placeholder or a basic display for job instructions.
*   **Enabled Features:** Provides a visual representation of G-code, which can be useful for monitoring or debugging job execution.

### `ui/src/components/panels/JobProgressPanel.vue`
*   **Purpose:** To display the progress of a job, likely using a stepper component to visualize different stages.
*   **Key Functionality:** Renders a `v-stepper` component with predefined steps.
*   **How it works:** This is a card component containing a `v-stepper`. The `steps` data property is currently hardcoded with example job stages, indicating it's a placeholder or an incomplete implementation for a more dynamic job progress tracker.
*   **Enabled Features:** Provides a visual indicator of job progress, helping operators understand the current stage of a machining operation.

### `ui/src/components/panels/ProbeMethodRender.vue`
*   **Purpose:** (Empty in provided code) Likely a placeholder for future functionality related to rendering visual representations or details of selected probe methods.
*   **Key Functionality:** Currently none.
*   **How it works:** (Not implemented).
*   **Enabled Features:** (Not yet enabled).

### `ui/src/components/panels/ProbeResultsPanel.vue`
*   **Purpose:** To display the results of probing operations, typically in a tabular format.
*   **Key Functionality:**
    *   Displays probe results in a `v-data-table`.
    *   Dynamically generates table headers based on visible axes.
    *   Includes an "Actions" column, potentially with buttons to act on specific probe results (e.g., set WCS).
    *   Currently uses placeholder data (`randomInt`) for demonstration.
*   **How it works:** Extends `BaseComponent.vue`. It dynamically generates table `headers` and `items` based on machine axes and workplace limits. The `items` are currently populated with random data, suggesting this is a work-in-progress or for demonstration purposes. Includes a "Probe" button, which likely triggers a probing cycle.
*   **Enabled Features:** Intended to provide a structured view of probing outcomes, allowing operators to review and potentially act on the results.

### `ui/src/components/panels/ProbeSelectorPanel.vue`
*   **Purpose:** To allow the operator to select a specific type of probing cycle (e.g., Bore, Boss, Corner) from a list of available options.
*   **Key Functionality:**
    *   Displays a grid of `v-card` components, each representing a different probe type.
    *   Each probe type card shows an icon, name, and description.
    *   Highlights the currently selected probe type.
    *   Provides a "Details" button to expand/collapse the description, especially on smaller screens, for better usability.
    *   Emits a `change` event with the selected probe type's index.
*   **How it works:** Extends `BaseComponent.vue`. It receives `probeTypes` as a prop (likely an object defined in `../../types/Probe.ts`). It uses `v-for` to render cards for each probe type. The `selectProbeType` method updates the `selectedProbeId` and emits the `change` event. `mustExpandProbeDetails` adapts the UI for mobile devices.
*   **Enabled Features:** Provides an intuitive and visually guided interface for operators to choose the appropriate probing strategy for their workpiece, enhancing ease of use.

### `ui/src/components/panels/ProbeSettingsPanel.vue`
*   **Purpose:** To provide a dynamic interface for configuring the specific parameters of a selected probing cycle.
*   **Key Functionality:**
    *   Dynamically renders various input fields (sliders, text fields, switches, chip groups) based on the `settings` defined for the chosen `probeType`.
    *   Supports different setting types: number, boolean, and enum-like options.
    *   Includes client-side validation and conditional input enabling/disabling based on the values of other settings.
    *   Emits a `change` event when settings are updated.
*   **How it works:** Extends `BaseComponent.vue`. It receives `probeType` and `probeCommand` as props. It uses a `v-form` for input management. Helper functions (`isNumberSetting`, `isBooleanSetting`, `isEnumSetting`) determine the appropriate UI control. The `allowInput` method checks conditions to enable/disable settings, providing a guided configuration experience.
*   **Enabled Features:** Offers a flexible and intelligent interface for operators to configure complex probing parameters, adapting to the specific requirements of each probe type and reducing configuration errors.

### `ui/src/components/panels/ProbingPanel.vue`
*   **Purpose:** The central panel for orchestrating the entire probing workflow, guiding the user from probe activation to cycle execution and status monitoring.
*   **Key Functionality:**
    *   **Tabbed Workflow:** Organizes the probing process into a clear, step-by-step tabbed interface: "Activate Probe", "Select Cycle", "Configure Settings", "Move to Position", "Review and Run", and "Status".
    *   **Probe Activation:** Provides a button to activate the probe (select the probe tool) and automatically advances to the next step upon activation.
    *   **Probe Cycle Selection:** Integrates the `mos-probe-selector-panel` for choosing the probe type.
    *   **Probe Settings Configuration:** Integrates the `mos-probe-settings-panel` for parameter setup.
    *   **Movement Guidance:** Includes a `cnc-movement-panel` (likely an override of a DWC component) for manual machine positioning.
    *   **Review:** Displays the dynamically generated G-code for the selected and configured probe cycle.
    *   **Run Cycle:** Button to execute the generated G-code command.
    *   **Real-time Status:** Shows animated progress bars for probe retries, points, and surfaces, providing live feedback during a running probe cycle.
*   **How it works:** Extends `BaseComponent.vue`. It manages the `tab` state to control the workflow. `probeActive` checks if the probe tool is selected. `activateProbe` sends `T<probe-tool-ID>`. `selectProbeType` updates the `probeType` and `probeCommand`. `getProbeCode` dynamically generates the G-code based on selected settings. `runProbe` sends `M5012` (reset probe counts), the generated G-code, and `M5012` again. It monitors global variables (`mosPRRS`, `mosPRPS`, `mosPRSS`, `mosPRRT`, `mosPRPT`, `mosPRST`) for real-time probe status and updates progress bars.
*   **Enabled Features:** Provides a comprehensive, user-friendly, and guided workflow for all probing operations, significantly enhancing user experience, reducing errors, and offering real-time feedback.

### `ui/src/components/panels/SafeMovementPanel.vue`
*   **Purpose:** To provide enhanced controls for safe manual movement (jogging) of the machine axes, including optional collision detection.
*   **Key Functionality:**
    *   Allows selection of the current axis for movement.
    *   Provides buttons for incremental movement in positive and negative directions.
    *   Includes a slider for adjusting the feed rate percentage for jogging.
    *   Features a dropdown menu to select a probe for "protected moves", enabling collision detection during manual jogging.
    *   Includes buttons for homing individual axes and all axes, setting the current position as workplace zero, and moving to workplace zero.
    *   Displays warnings for unhomed axes.
*   **How it works:** Extends a Vue component (likely inheriting from `BaseComponent.vue` indirectly). It manages `protectedMoveProbeID` in the plugin cache for persistence. `protectedMoveProbes` dynamically lists available probes. The `sendMoveCode` method constructs and sends G-code for movement, incorporating protected move logic (checking probe status, axis limits, and probe type) before sending commands. `setWorkplaceZero` and `goToWorkplaceZero` send G-code to manage WCS origins.
*   **Enabled Features:** Offers a dedicated and robust interface for controlled, safe manual jogging, with optional collision detection, crucial during setup and probing. It also provides quick access to homing and WCS origin management.

### `ui/src/components/panels/SpindleControlPanel.vue`
*   **Purpose:** To display the status of configured spindles.
*   **Key Functionality:**
    *   Lists all configured spindles in a simple table.
    *   Displays the current RPM for each spindle.
    *   Shows an icon indicating the spindle's state (clockwise, counter-clockwise, paused/stopped).
*   **How it works:** Extends `BaseComponent.vue`. It filters `store.state.machine.model.spindles` to show only configured spindles. The `spindleIcon` method dynamically determines the appropriate icon based on the spindle's current RPM.
*   **Enabled Features:** Provides a quick and clear overview of spindle status, which is important for monitoring machining operations.

### `ui/src/components/panels/StatusPanel.vue`
*   **Purpose:** (Empty in provided code) This component is currently a placeholder. It is likely intended to display general machine status or MillenniumOS-specific status information.
*   **Key Functionality:** Currently none.
*   **How it works:** (Not implemented).
*   **Enabled Features:** (Not yet enabled).

### `ui/src/components/panels/WorkplaceOriginsPanel.vue`
*   **Purpose:** To display and manage Work Coordinate System (WCS) origins (G54-G59.3).
*   **Key Functionality:**
    *   Displays a table listing all available workplaces.
    *   Shows the X, Y, Z offsets for each workplace.
    *   Allows direct editing of individual axis offsets for each workplace using `mos-axis-input` components.
    *   Clearly indicates the currently active workplace.
    *   Provides buttons to activate a specific workplace and to clear a workplace's offsets (resetting them to zero).
*   **How it works:** Extends `BaseComponent.vue`. It dynamically generates table `headers` and `items` based on `limits.workplaces` and visible axes. It uses `mos-axis-input` for inline editing of offsets. The `switchWorkplace` method sends G-code (e.g., `G54`, `G55`) to activate a workplace. The `clearWorkplace` method sends `G10 L2 P<workplace-number> X0 Y0 Z0` to reset offsets. `workplaceItemClass` and `selectWorkplace` handle visual selection and styling.
*   **Enabled Features:** Provides comprehensive management of WCS origins, enabling operators to define, modify, activate, and reset coordinate systems directly from the UI. This is fundamental for setting up jobs and managing multiple work offsets.

---

## Override Components (`ui/src/components/overrides/`)

MillenniumOS uses override components to replace or extend existing Duet Web Control (DWC) UI elements, seamlessly integrating its custom functionality into the standard DWC interface.

### `ui/src/components/overrides/index.ts`
*   **Purpose:** Serves as the central entry point for registering all UI overrides within MillenniumOS.
*   **Key Functionality:** Orchestrates the loading and application of panel and route overrides.
*   **How it works:** It imports and executes `panels/index.ts` and `routes/index.ts` from the overrides directory. These sub-modules then handle the specific component and route overriding logic.
*   **Enabled Features:** Centralizes the mechanism for MillenniumOS to customize the default DWC user interface.

### `ui/src/components/overrides/panels/index.ts`
*   **Purpose:** Registers specific MillenniumOS override components that replace standard DWC panels.
*   **Key Functionality:** Replaces default DWC panels with MillenniumOS's customized versions.
*   **How it works:** It imports `CNCContainerPanel.vue`, `CNCDashboardPanel.vue`, and `CNCMovementPanel.vue` and registers them as Vue components using the *same names* as the original DWC components (e.g., `Vue.component("cnc-movement-panel", CNCMovementPanel);`). This ensures that when DWC attempts to render its default panels, it instead renders the MillenniumOS custom versions.
*   **Enabled Features:** Allows MillenniumOS to deeply customize the appearance and behavior of core DWC panels, integrating its features directly into the standard DWC interface for a more cohesive user experience.

### `ui/src/components/overrides/panels/CNCContainerPanel.vue`
*   **Purpose:** An override for a standard DWC container panel, designed to integrate MillenniumOS-specific status information and layout.
*   **Key Functionality:** Displays a consolidated view of critical machine and MillenniumOS-specific status, including:
    *   General machine status (`status`).
    *   Current active workplace and its validity (`currentWorkplace`, `currentWorkplaceValid`).
    *   Current tool information (number, name, radius, Z-offset).
    *   Status of the touch probe and toolsetter (enabled/disabled, triggered/not triggered).
    *   Current rotation compensation angle.
    *   Integrates `mos-cnc-axes-position` and `mos-spindle-control-panel` for a comprehensive overview.
*   **How it works:** Extends `BaseComponent.vue`. It retrieves various machine state properties from the store and uses helper methods (`probeColor`, `probeText`, `probeIcon`, `toolNameShort`, `currentWorkplaceColor`, `currentWorkplaceText`) to format and display data. It uses Vuetify components (`v-card`, `v-simple-table`, `v-chip`, `v-tooltip`) for presentation.
*   **Enabled Features:** Provides a rich, consolidated view of critical machine and MillenniumOS-specific status information directly within a customized DWC panel, enhancing operator awareness and control.

### `ui/src/components/overrides/panels/CNCDashboardPanel.vue`
*   **Purpose:** An override for the main CNC dashboard panel in DWC, customizing its layout and content to prioritize MillenniumOS features.
*   **Key Functionality:** Arranges various panels, including `mos-cnc-axes-position` and `mos-spindle-control-panel`, within a responsive grid layout to form the main dashboard view.
*   **How it works:** Extends `BaseComponent.vue` and uses Vuetify's grid system (`v-row`, `v-col`) to structure the dashboard. It embeds other MillenniumOS custom panels to create a tailored dashboard experience.
*   **Enabled Features:** Customizes the main DWC dashboard to prominently feature MillenniumOS's axis position and spindle control panels, providing a more integrated and relevant overview for MillenniumOS users.

### `ui/src/components/overrides/panels/CNCMovementPanel.vue`
*   **Purpose:** An override for the standard DWC movement panel, enhancing it with MillenniumOS-specific features like WCS selection and protected moves.
*   **Key Functionality:**
    *   Integrates WCS selection (`v-select v-model="currentWorkplace"`).
    *   Provides a button to enable/disable "protected moves" and select the probe to use for collision detection during manual jogging.
    *   Includes standard homing buttons (`G28`) for all axes and individual axes.
    *   Offers incremental movement buttons for each axis with customizable step sizes (configured via `moveStepDialog`).
    *   Features buttons for "Set Workplace Zero" and "Go to Workplace Zero".
    *   Displays alerts for unhomed axes.
*   **How it works:** Extends a Vue component (likely inheriting from `BaseComponent.vue` indirectly). It manages `currentWorkplace` and `protectedMoveProbeID` (persisted in plugin cache). `protectedMoveProbes` dynamically lists available probes. The `sendMoveCode` method constructs and sends G-code for movement, incorporating protected move logic (checking probe status, axis limits, and probe type) before sending commands. `setWorkplaceZero` and `goToWorkplaceZero` send G-code to manage WCS. `moveStepDialog` allows customization of move step distances.
*   **Enabled Features:** Replaces the default DWC movement panel with a more powerful version that integrates MillenniumOS's safe movement, WCS management, and protected move capabilities, significantly improving manual control and safety.

### `ui/src/components/overrides/routes/index.ts`
*   **Purpose:** Responsible for overriding specific DWC routes with MillenniumOS's custom components.
*   **Key Functionality:** Intercepts route navigation and replaces original DWC components with MillenniumOS custom components for specific routes.
*   **How it works:** It uses a `VueRouter.beforeEach` navigation guard. For each defined override pair (original DWC component, MillenniumOS replacement component), it checks if the current route's default component matches the original. If so, it dynamically replaces the original component with the MillenniumOS replacement.
*   **Enabled Features:** Allows MillenniumOS to completely replace or augment specific DWC pages with its own custom UI, providing a seamless and integrated user experience for customized functionalities.

### `ui/src/components/overrides/routes/Job/Status.vue`
*   **Purpose:** An override for the standard DWC Job Status page, customizing its layout and content to integrate MillenniumOS-specific job information.
*   **Key Functionality:** Arranges various job-related panels (`job-progress`, `job-control-panel`, `mos-job-code-panel`, `job-estimations-panel`, `job-data-panel`, `speed-factor-panel`, `z-babystep-panel`, `macro-list`) within a responsive grid layout.
*   **How it works:** Extends a Vue component (likely inheriting from `BaseComponent.vue` indirectly) and uses Vuetify's grid system to structure the job status page. It imports and uses several other DWC components (`job-progress`, `job-control-panel`, etc.) alongside MillenniumOS's custom `mos-job-code-panel` to create a tailored job status view.
*   **Enabled Features:** Customizes the DWC job status page to provide a more integrated and MillenniumOS-centric view of ongoing jobs, including custom job code display and other relevant information.