# Millennium Machines GCode Flavour

## Misc

### `G27` - PARK
Parking is used widely throughout probing and tool changing to move the spindle and work area to safe, easily accessible locations. CNC Firmwares do not always provide a generic park function (including RRF) so we implement our own.

### `G37` - PROBE TOOL LENGTH
When using multiple milling tools, we must compensate for length differences between the tools. G37 can be used to (re-)calculate the length of the current tool in relation to a reference surface. `G37` is used widely by CNC mills to probe tool lengths but is not implemented by RRF, so again we implement our own.

### `M7500` - PROMPT TOUCHPROBE INSERTION

### `M7501` - PROMPT TOUCHPROBE REMOVAL

---

## Probing

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


### Three Axis

#### `G6511` - VISE CORNER (CUBOID)

---

## Tool Management

### `T<N>` - CHANGE NEXT TOOL INDEX

### `M6` - PERFORM TOOL CHANGE

### `M4000` - DEFINE TOOL

### `M4001` - FORGET TOOL

---

## Variable Spindle Speed Control

### `M7000` - ENABLE VSSC

### `M7001` - DISABLE VSSC


