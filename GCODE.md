# Millennium Machines GCode Flavour

## Misc

### `G27` - PARK

Parking is used widely throughout probing and tool changing to move the spindle and work area to safe, easily accessible locations. CNC Firmwares do not always provide a generic park function (including RRF) so we implement our own.

### `G37` - PROBE TOOL LENGTH

When using multiple milling tools, we must compensate for length differences between the tools. G37 can be used to (re-)calculate the length of the current tool in relation to a reference surface. `G37` is used widely by CNC mills to probe tool lengths but is not implemented by RRF, so again we implement our own.

### `G37.1` - PROBE Z SURFACE WITH CURRENT TOOL

When there is no toolsetter available, it is necessary to re-zero the Z origin after changing tools - because the new tool will never be installed with exactly the same length as the previous one. After a tool change, this command will be called automatically instead of `G37` if no toolsetter is available, and will walk the operator through manual re-zeroing of the Z origin. This has some caveats, in that if you machine off the surface that is used as your zero point then re-zeroing will be problematic - the operator must account for this in their CAM profile, to make sure that their Z origin makes sense.

### `M3000` - PROMPT OPERATOR WITH CONFIRMABLE DIALOG

Takes both `R` (title) and `S` (message) string parameters, and will display an RRF dialog box. If the machine is currently processing a file and not paused, the dialog box will contain Continue, Pause and Cancel options. If M3000 is called while the machine is not processing a file, only Continue and Cancel options will be shown. This can be used by post-processors to display messages to the operator.

### `M4005` - CHECK MILLENNIUMOS VERSION

```gcode
; Abort if loaded MillenniumOS version is not v0.3.0
M4005 V"v0.3.0"
```

The MillenniumOS post-processor and macros are tightly coupled across versions. This command aborts an active job if the version of MillenniumOS that is running in RRF does not match the version of the post-processor that generated the job.

### `M5010` - RESET STORED WCS DETAILS

```gcode
; Reset Work Offset 0 centre position and radius.
M5010 W0 R5
```

Reset the stored details for a given WCS. Different fields are used for different types of probing operations, and we want to reset these values before running a probing cycle - so if previous values existed but the probing cycle failed we would not end up using the previous valid values.

`M5010` uses a bitmask-style integer field to select which WCS detail fields to reset for a particular WCS.

### `M5011` - APPLY ROTATION COMPENSATION

```gcode
; Apply rotation compensation using details from current work offset
M5011

; Apply rotation compensation using work offset 0 values
M5011 W0
```

Looks up stored rotation values from WCS details and if a rotation value is given, will prompt the operator to apply it as a rotation compensation value using the inbuilt `G68` command.

### `M6515` - CHECK CO-ORDINATES ARE WITHIN MACHINE LIMITS

Takes at least one of X, Y and Z co-ordinates and checks that they are within the axes limits of the machine, otherwise triggers an abort. This is used by other macros to make sure we do not try to move outside of machine limits.

### `G6516` - CHECK MACHINE POSITION MATCHES CO-ORDINATES

Takes at least one of X, Y and Z co-ordinates and checks that the current machine position in the given axes match the arguments. This is used by other macros to make sure the machine has moved to where we expected it to. This is mostly used after a probing move to make sure that the probe was not triggered early by a collision.

### `G6550` - PROTECTED MOVE

Takes at least one of X, Y and Z co-ordinates as the target location, and an optional probe ID (I). If the probe ID is given, it will attempt to move to the target location while watching the specified probe for activation due to collision. If a probe ID is not given, this move acts like a G1 move to the target, implementing an unprotected move at the manual probing speed. This macro is called by probing macros to try to avoid damaging any probe due to accidental collisions.

### `M7601` - PRINT WORKPLACE DETAILS

Outputs any stored probing details either for the current workplace, or the workplace given by offset `W`. It will only output probed values that are not null.

### `G8000` - RUN CONFIGURATION WIZARD

Triggered when installing MillenniumOS for the first time, and can be called later to reconfigure MillenniumOS. Runs through a modal-driven configuration wizard prompting the user for all of the settings required to run MillenniumOS properly.

### `M8001` - DETECT PROBE BY STATUS CHANGE

Iterates through all configured probes every &lt;n&gt;ms, checking to see if their values have changed. This can be used to identify the right probe via user input when configuring MillenniumOS.

### `M8002` - WAIT FOR PROBE STATUS CHANGE BY ID

```gcode
; Wait for probe with ID 1 to change state
M8002 K1
```

Wait for the probe given by ID `K` to change state. This is used to detect the installation of a touch probe or similar where the circuit or device may not be NC, to avert situations where the operator has installed the probe but forgotten to plug it in.

### `M8003` - LIST CHANGED GP INPUT PINS SINCE LAST CALL

```gcode
; Save current state of GP input pins
M8003

; Store list of changed pins in global.mosGPV
M8003

; Update list of changed pins
M8003
```

Stores a list of the general purpose input pins whose states have changed since the last call to `M8003`. This is used to identify Spindle Feedback pins during the configuration wizard process.

### `M8004` - WAIT FOR GP INPUT PIN STATUS CHANGE BY ID

```gcode
; Wait for general purpose input 0 to change state
M8004 K0
```

Waits for a general purpose input pin to change state. The state that is changed to is unimportant, just that the state changes. This code is used by `M3.9` and `M5.9` when spindle feedback is enabled to wait until the VFD reports that it has reached the target speed.


### `M9999` - RELOAD MILLENNIUMOS

Triggers a reload of MillenniumOS using `daemon.g`. This can be used when developing or updating values from `mos-user-vars.g` but is _not_ suitable for use when a new version of MillenniumOS has been installed - you _MUST_ restart!

---

## Probing

### META

#### `G6600` - PROBE WORKPIECE

Called by the post-processor to indicate that workpiece should be probed to set WCS origin.

If the post knows what _type_ of workpiece probe should be executed, it can call the specific probing operation directly (e.g. `G6500`, `G6501` etc). Calling `G6600` will prompt the operator to select a probing methodology based on their knowledge of the work piece.

### Two Axis

#### `G6500` - BORE

Guided bore probe, prompts the user for approximate diameter, overtravel, approximate center position and probe depth.
Executes `G6500.1` with the relevant parameters to run the actual probe.

##### `G6500.1` - BORE - EXECUTE

Calculates the center of a bore and its radius, by running 3 probes outwards from the chosen starting position towards the edge of the bore. The overtravel is added to the radius of the bore and this sets the distance moved from the
center point in each of the 3 directions before the probe cycle will error if it does not trigger.

#### `G6501` - BOSS

Guided boss probe, prompts the user for approximate diameter, clearance, overtravel, approximate center position and probe depth.
Executes `G6501.1` with the relevant parameters to run the actual probe.

##### `G501.1` - BOSS - EXECUTE

Calculates the center of a boss and its radius, by running 3 probes inwards towards the operator-chosen center of the bore. The overtravel is subtracted from the radius of the boss to identify the target location of each probe, and the clearance is added to the radius of the boss to identify the starting locations.

#### `G6502` - RECTANGLE POCKET

#### `G6503` - RECTANGLE BLOCK

Guided rectangle block probe, prompts the user for an approximate width (X), length (Y), overtravel and clearance, an approximate center position and probe depth. Executes `G6503.1` with the relevant parameters to run the actual probe.

##### `G6503.1` - RECTANGLE BLOCK - EXECUTE

Calculates the center of a rectangle block, its surface angles, rotation angle (in relation to the X axis) and its dimensions based on 8 different probes.
Using the provided width, height, clearance and starting location, we probe inwards from the expected edges of each surface by the clearance distance. We probe each surface twice to get a surface angle, and validate that the block itself is both rectangular and how far it is rotated from the X axis.

#### `G6504` - WEB X

Not implemented.

#### `G6505` - POCKET X

Not implemented.

#### `G6506` - WEB Y

Not implemented.

#### `G6507` - POCKET Y

Not implemented.

#### `G6508` - OUTSIDE CORNER

Guided outside corner probe, prompts the user for an approximate width (X) and length (Y) of the 2 surfaces that make up the corner, a clearance and overtravel distance, a probing depth, a starting location and the corner that we want to probe (front left, back right etc). Executes `G6508.1` with the relevant parameters to run the actual probe.

##### `G6508.1` - OUTSIDE CORNER - EXECUTE

Calculates the corner position of a square corner on a workpiece in X and Y, as well as calculating the rotation angle and corner angle of the item. Using the provided width, height, clearance, overtravel and starting location, we move outwards along each surface forming the corner, probing at 2 locations on each surface to find their angles, and then calculate where these surfaces intersect at the relevant corner.

#### `G6509` - INSIDE CORNER

Not implemented.

### Single Axis

#### `G6510` - SINGLE SURFACE

Guided single surface probe, which prompts the user for a starting location, overtravel distance, which surface to probe, a maximum probing distance and for X and Y surfaces, a probing depth below the starting location. Can be used to probe the Z height of a workpiece, or a single surface on X or Y if the operator knows these are aligned with the machine axes. This macro only probes a single point so cannot calculate surface angles.

##### `G6510.1` - SINGLE SURFACE - EXECUTE

Calculates the X, Y or Z co-ordinate of a surface using the provided starting location, surface number, probing distance and depth.

#### `G6511` - PROBE REFERENCE SURFACE

Probes the touch probe reference surface in Z, and sets the touch probe activation point. Will be called automatically when changing to the touch probe with the feature enabled.

### Three Axis

#### `G6520` - VISE CORNER

Guided probing macro that combines OUTSIDE CORNER and SINGLE SURFACE (Z) macros to zero all 3 axes of a WCS in a single probing operation. This macro prompts the user for the required parameters for the OUTSIDE CORNER macro, as well as a starting location. It calls the macros in sequence, probing the Z surface first before moving outwards and probing each X and Y surface that forms the corner.

##### `G6520.1` - VISE CORNER - EXECUTE

Executes a Vise Corner probe using the parameters gathered by the operator. Runs a Z probe first, then each corner probe after and sets the WCS origin of all 3 axes at once.

### Low-Level

#### `G6512` - SINGLE PROBE

The low-level probing macro which is used by all of the above probing mechanisms. Implements manual or automated probing using the sub-macros `G6512.1` and `G6512.2`. These handle protected moves, validation of probing points and averages, tolerances and retries.

---

## Drilling

### `G73` - DRILL CANNED CYCLE - PECK DRILLING WITH PARTIAL RETRACT

```gcode
; At X=10 and Y=10, peck 1mm at a time at 500mm/min,
; from Z=-5 to Z=-10, retracting by 1mm after each peck.
; We then retract to Z=-5.
G73 F500 R-5 Q1 Z-10 X10 Y10
```

Run a peck drilling with partial retract cycle. **WARNING**: - this may not clear enough chips. You are likely better off using a drill cycle that retracts fully.

### `G80` - CANNED CYCLE CANCEL

Resets all variables stored about the current canned cycle. After the first call to a canned cycle macro containing drilling details, subsequent calls only need to contain the X and Y location of the holes. By calling `G80`, these stored details can be reset so that stored details _MUST_ be provided by the next canned drilling cycle call.

### `G81` - DRILL CANNED CYCLE - FULL DEPTH

```gcode
; At X=10 and Y=10, drill down at 500mm/min,
; from Z=-5 to Z=-10, in one movement.
; We then retract to Z=-5.
G81 F500 R-5 Z-10 X10 Y10
```

Run a full-depth drilling cycle with _NO_ retraction. **WARNING**: - unless you are drilling very shallow holes, use a drilling cycle with retraction.

### `G83` DRILL CANNED CYCLE - PECK DRILLING WITH FULL RETRACT

```gcode
; At X=10 and Y=10, peck 1mm at a time at 500mm/min,
; from Z=-5 to Z=-10, retracting to Z=-5 after each peck.
G83 F500 R-5 Q1 Z-10 X10 Y10
```

Working in the same manner as `G73`, this cycle retracts above the initial Z position after each peck. This allows for easier chip clearing during the drilling cycle. If in doubt, use this cycle type for canned drilling as it is the least likely to break your drill bit if chip clearing is an issue.

---

## Tool Management

### `M4000` - DEFINE TOOL

```gcode
; Define tool index 14 as a 3mm endmill
M4000 P14 R1.5 S"3mm Endmill"

; Define tool index 49 as a probe with deflection values for X and Y
M4000 P49 R1 S"Touch Probe" X0.05 Y0.01
```

We need to store additional details about tools that RRF is not currently able to accommodate natively - this includes tool radius and deflection values (for probes). `M4000` stores these custom values in a global vector that allows us to use them, while configuring RRF with the relevant tool details using `M563`.

### `M4001` - FORGET TOOL

```gcode
; Reset tool 14 to default values
M4001 P14
```

Resets our custom tool table and RRF's tool table at the given index.

### `T<N>` - EXECUTE TOOL CHANGE

```gcode
; Trigger toolchange to tool ID 4
T4
```

This macro is built in to RRF, using the `t{free,pre,post}.g` files. If the target tool number is specified, then these files are executed in order. The operator is prompted to change to the correct tool and if this tool is a probe tool, will be asked to verify that the tool is connected by triggering it manually before proceeding.

---

## Coolant Control

### `M7.1` - ENABLE AIR BLAST

Enables the GPIO output associated with air-blast, set by the operator during the configuration wizard.

### `M7` - ENABLE MIST

Enables the GPIO output associated with unpressurized coolant, set by the operator during the configuration wizard. If air blast (`M7.1`) is not already enabled, then this will be enabled prior to activating the coolant output.

### `M8` - ENABLE FLOOD

For those mad enough to build flood coolant into a DIY CNC machine, `M8` enables pressurised flood coolant on the GPIO output associated by the operator during the configuration wizard.

### `M9` - CONTROL ALL COOLANTS

By default, this turns off any enabled coolant outputs. If called with the `R1` parameter, will restore coolant output states to those saved during the most recent pause. This macro is called during the resume process to re-enable coolant.

---

## Spindle Control

### Spindle Wait Functionality

#### `M3.9` - START SPINDLE CLOCKWISE AND WAIT

```gcode
; Start spindle 0 at 18000 RPM
M3.9 S18000 P0

; Start spindle assigned to current tool at 8000 RPM
M3.9 S8000
```

Wrapping the inbuilt `M3` command, `M3.9` starts the spindle in the clockwise direction at a particular speed and waits for it to accelerate to the target speed. If spindle feedback is configured, this command waits for a GPIO input to change state before returning. If spindle feedback is not configured, a static delay is used to make sure the spindle is up to speed before returning. The static speed used for this is timed by the operator during the wizard process.

#### `M5.9` - STOP SPINDLE AND WAIT

```gcode
; Stop spindle
M5.9
```

Wrapping the inbuilt `M5` command, `M5.9` stops all spindles and waits for them to decelerate. Like `M3.9`, this either uses a pin state-change if spindle feedback is configured, or a static delay if not, to make sure we do not proceed until the spindle is stationary.

### Variable Spindle Speed Control

Variable Spindle Speed Control (VSSC) constantly adjusts the speed of the spindle up and down over a set range to avoid resonance between the tool and the workpiece building up at constant RPMs. It can provide a quality boost in situations where resonances would otherwise occur.

#### `M7000` - ENABLE VSSC

```gcode
; Enable VSSC with a period of 2000 ms and a variance of 100 RPM
M7000 P2000 V100
```

Enable Variable Spindle Speed Control and configure it.

#### `M7001` - DISABLE VSSC

Disable Variable Spindle Speed Control.

---

## Debugging

### `M7600` - OUTPUT ALL KNOWN VARIABLES

Sometimes it is necessary to debug MillenniumOS or RRF, and this macro allows outputting the macro variables that MillenniumOS uses in a manner that can be attached to tickets or discord messages to aid debugging. Call it with the `D1` parameter to enable additional RRF object model output that can help to debug the odder issues.
