# Millennium Machines GCode Flavour

## RRF Useful Codes
G30
G38.2...
M675
M585

## Misc

#### `G27` - PARK
Parking is used widely throughout probing and tool changing to move the spindle and work area to safe, easily accessible locations. CNC Firmwares do not always provide a generic park function (including RRF) so we implement our own.

#### `G37` - PROBE TOOL LENGTH
When using multiple milling tools, we must compensate for length differences between the tools. G37 can be used to (re-)calculate the length of the current tool in relation to a reference surface. `G37` is used widely by CNC mills to probe tool lengths but is not implemented by RRF, so again we implement our own.

#### `M7500` - PROMPT TOUCHPROBE INSERTION
Ask the user to install the touch probe into the spindle and plug it in. Most cheap 3D touch probes are normally open, which means we cannot detect programmatically if the touch probe is installed.

`M7500` prompts the user with a modal that they should dismiss when they are ready to continue the probing process.

#### `M7501` - PROMPT TOUCHPROBE REMOVAL
Ask the user to remove the touch probe from the spindle. This confirms that we will not spin up the touch probe by making sure a user has to dismiss a modal after removing the touch probe.

#### `M8001` - CHECK PROBE STATUS CHANGE
Iterates through all configured probes every <n>ms, checking to see if their values have changed. This can be used to identify the right probe via user input when configuring MillenniumOS.

---

## Probing

### META

#### `G6600` - PROBE WORKPIECE
Called by the post-processor to indicate that workpiece should be probed to set WCS origin.

If the post knows what _type_ of workpiece probe should be executed, it can call the specific probing operation directly (e.g. `G6500`, `G6501` etc). Calling `G6600` will prompt the operator to select a probing methodology based on their knowledge of the work piece.

### Two Axis

#### `G6500` - BORE

#### `G6501` - BOSS

#### `G6502` - RECTANGLE POCKET

#### `G6503` - RECTANGLE BLOCK

#### `G6504` - WEB X

#### `G6505` - POCKET X

#### `G6506` - WEB Y

#### `G6507` - POCKET Y

#### `G6508` - OUTSIDE CORNER

#### `G6509` - INSIDE CORNER

### Single Axis

#### `G6510` - SINGLE SURFACE

#### `G6511` - PROBE REFERENCE SURFACE
  - Calls `G6512`, probing from z-max towards z-min

### Three Axis

#### `G6520` - VISE CORNER (CUBOID)

### Misc

#### `G6550` - PROTECTED MOVE
Uses `G38.3` internally to perform a protected move against a given probe ID.
The machine will move at the given probe's travel speed. The sub codes
(G6550.1 and G6550.2) are used to move towards and away from a work piece.



---

## Tool Management

#### `T<N>` - CHANGE NEXT TOOL INDEX

#### `M6` - PERFORM TOOL CHANGE

#### `M4000` - DEFINE TOOL

#### `M4001` - FORGET TOOL

---

## Spindle Control

### Variable Spindle Speed Control

#### `M7000` - ENABLE VSSC

#### `M7001` - DISABLE VSSC

---

## Variable Control

#### `M7600` - OUTPUT ALL KNOWN VARIABLES