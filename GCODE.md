# Millennium Machines GCode Flavour

## Misc

### `G27` - PARK

Parking is used widely throughout probing and tool changing to move the spindle and work area to safe, easily accessible locations. CNC Firmwares do not always provide a generic park function (including RRF) so we implement our own.

### `G37` - PROBE TOOL LENGTH

When using multiple milling tools, we must compensate for length differences between the tools. G37 can be used to (re-)calculate the length of the current tool in relation to a reference surface. `G37` is used widely by CNC mills to probe tool lengths but is not implemented by RRF, so again we implement our own.

### `M3000` - PROMPT OPERATOR WITH CONFIRMABLE DIALOG

Takes both `R` (title) and `S` (message) string parameters, and will display an RRF dialog box. If the machine is currently processing a file and not paused, the dialog box will contain Continue, Pause and Cancel options. If M3000 is called while the machine is not processing a file, only Continue and Cancel options will be shown. This can be used by post-processors to display messages to the operator.

### `M6515` - CHECK CO-ORDINATES ARE WITHIN MACHINE LIMITS

Takes at least one of X, Y and Z co-ordinates and checks that they are within the axes limits of the machine, otherwise triggers an abort. This is used by other macros to make sure we do not try to move outside of machine limits.

### `G6516` - CHECK MACHINE POSITION MATCHES CO-ORDINATES

Takes at least one of X, Y and Z co-ordinates and checks that the current machine position in the given axes match the arguments. This is used by other macros to make sure the machine has moved to where we expected it to. This is mostly used after a probing move to make sure that the probe was not triggered early by a collision.

### `G6550` - PROTECTED MOVE

Takes at least one of X, Y and Z co-ordinates as the target location, and an optional probe ID (I). If the probe ID is given, it will attempt to move to the target location while watching the specified probe for activation due to collision. If a probe ID is not given, this move acts like a G1 move to the target, implementing an unprotected move at the manual probing speed. This macro is called by probing macros to try to avoid damaging any probe due to accidental collisions.

### `G8000` - RUN CONFIGURATION WIZARD

Triggered when installing MillenniumOS for the first time, and can be called later to reconfigure MillenniumOS. Runs through a modal-driven configuration wizard prompting the user for all of the settings required to run MillenniumOS properly.

### `M8001` - CHECK PROBE STATUS CHANGE

Iterates through all configured probes every &lt;n&gt;ms, checking to see if their values have changed. This can be used to identify the right probe via user input when configuring MillenniumOS.

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

Calculates the center of a boss and its' radius, by running 3 probes inwards towards the operator-chosen center of the bore. The overtravel is subtracted from the radius of the boss to identify the target location of each probe, and the clearance is added to the radius of the boss to identify the starting locations.

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

---

## Tool Management

### `M4000` - DEFINE TOOL

We need to store additional details about tools that RRF is not currently able to accommodate natively - this includes tool radius and deflection values (for probes). `M4000` stores these custom values in a global vector that allows us to use them, while configuring RRF with the relevant tool details using `M563`.

### `M4001` - FORGET TOOL

Resets our custom tool table and RRF's tool table at the given index.

### `T<N>` - EXECUTE TOOL CHANGE

This macro is built in to RRF, using the `t{free,pre,post}.g` files. If the target tool number is specified, then these files are executed in order. The operator is prompted to change to the correct tool and if this tool is a probe tool, will be asked to verify that the tool is connected by triggering it manually before proceeding.

---

## Spindle Control

### Variable Spindle Speed Control

Variable Spindle Speed Control (VSSC) constantly adjusts the speed of the spindle up and down over a set range to avoid resonance between the tool and the workpiece building up at constant RPMs. It can provide a quality boost in situations where resonances would otherwise occur.

#### `M7000` - ENABLE VSSC

Enable Variable Spindle Speed Control.

#### `M7001` - DISABLE VSSC

Disable Variable Spindle Speed Control

---

## Debugging

### `M7600` - OUTPUT ALL KNOWN VARIABLES

Sometimes it is necessary to debug MillenniumOS or RRF, and this macro allows outputting the macro variables that MillenniumOS uses in a manner that can be attached to tickets or discord messages to aid debugging. Call it with the `D1` parameter to enable additional RRF object model output that can help to debug the odder issues.
