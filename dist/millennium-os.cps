/**
 * MillenniumOS v0.5.0-1-gca8a344-dirty Postprocessor for Fusion360.
 *
 * This post-processor assumes that most complex functionality like
 * tool changes and work coordinate setting is handled in the machine firmware.
 *
 * Calls in to these systems should be a single macro call, preferably using a custom
 * gcode rather than macro filename, and how the gcode handles the task in question
 * (e.g. tool length calculation being automatic or manual) is a concern for the
 * firmware, _not_ this post-processor.
 *
 * As such, it is a very simple post-processor and only supports 3 axis and one
 * spindle. It will NOT output any gcode that we are not 100% certain
 * will be safe, based on the following assumptions:
 *
 * - Your G27 (Park) macro raises Z away from the work piece _before_ running M5.
 * - It is the responsibility of your macros to run M5 where needed!
 * - It is the responsibility of your macros and firmware to run any safety checks.
 */

// Add some useful functions not available in Fusion360
Object.values = Object.values || function(o){return Object.keys(o).map(function(k){return o[k]})};

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g,
        function (a, b) {
            var r = o[b];
            switch(typeof r) {
              case 'string':
                // Allow only alphanumeric characters, colons, periods,
                // commas, underscores, hyphens and spaces. Replace all
                // double quotes with two double quotes so these are escaped
                // by RRF when outputted.
                return r.replace(/([^"0-9a-z\.:,=_\-\s])/gi, "").replace(/"/g, '""')
              case 'number':
                return r;
              default:
                return a;
            }
        }
    );
};

String.prototype.capitalize = function() {
    return this[0].toUpperCase() + this.slice(1);
};

// Set display configuration of Postprocessor in Fusion360
description = "MillenniumOS v0.5.0-1-gca8a344-dirty for Milo v1.5";
longDescription = "MillenniumOS v0.5.0-1-gca8a344-dirty Post Processor for Milo v1.5.";
vendor = "Millennium Machines";
vendorUrl = "https://www.millennium-machines.com/";
legal = "Copyright (C) 2012-2018 by Autodesk, Inc. 2023-2024 Millennium Machines";

// Postprocessor engine settings
certificationLevel = 2;
minimumRevision = 24000;

// Output file format settings
extension = "gcode";
setCodePage("ascii");

// Machine capabilities
capabilities = CAPABILITY_MILLING | CAPABILITY_ROTARY;
tolerance    = spatial(0.002, MM);

var aAxis = createAxis({coordinate:0, table:true, axis:[1, 0, 0], cyclic:true, preference:1});
machineConfiguration = new MachineConfiguration(aAxis);
setRotation(aAxis);

// Postprocessor settings specific to machine capabilities
minimumChordLength    = spatial(0.1, MM);  // Minimum delta movement when interpolating circular moves
minimumCircularRadius = spatial(0.1, MM);  // Minimum radius of circular moves that can be interpolated
maximumCircularRadius = spatial(1000, MM); // Maximum radius of circular moves that can be interpolated
minimumCircularSweep  = toRad(0.1);        // Minimum angular sweep of circular moves
maximumCircularSweep  = toRad(90);         // Maximum angular sweep of circular moves, set to 90 as we use Radius output for arcs
allowHelicalMoves     = true;              // Output helical moves as arcs
allowSpiralMoves      = false;             // Linearize spirals (circular moves with a different starting and ending radius)
allowedCircularPlanes = undefined;         // Allow arcs on all planes

// Base WCS number, offset is added to this
var wcsBase = 53;

// Define WCS probing modes
var wcsProbeMode = {
  NONE: "NONE",
  ATSTART: "AT_START",
  ONCHANGE: "ON_CHANGE"
};

var wcsProbeModeProperty = [
  { title: "None (Expert Mode)", id: wcsProbeMode.NONE },
  { title: "At Start", id: wcsProbeMode.ATSTART },
  { title: "On Change", id: wcsProbeMode.ONCHANGE }
];

var warpSpeedMode = {
  NONE: "NONE",
  CLEARANCE: "CLEARANCE",
  RETRACT: "RETRACT",
  ZERO: "ZERO"
}

var warpSpeedModeProperty = [
  { title: "None", id: warpSpeedMode.NONE },
  { title: "Clearance", id: warpSpeedMode.CLEARANCE },
  { title: "Retract", id: warpSpeedMode.RETRACT },
  { title: "Zero", id: warpSpeedMode.ZERO }
];

// Property groups for user-configurable properties
groupDefinitions = {
  spindle: {
    title: "Spindle Setup",
    description: "Spindle configuration",
    collapsed: false,
    order: 20
  }
};

// Properties configurable by the user
properties = {
  outputMachine: {
    title: "Output machine details",
    description: "Output machine settings header.",
    group: "formats",
    scope: "post",
    type: "boolean",
    value: true
  },
  outputVersion: {
    title: "Output version details",
    description: "Output version details header.",
    group: "formats",
    scope: "post",
    type: "boolean",
    value: true
  },
  outputTools: {
    title: "Output tools",
    description: "Output tool details. If disabled, the firmware will not be pre-configured with tool details - you must configure them manually with the correct tool numbers before running the job.",
    group: "formats",
    scope: "post",
    type: "boolean",
    value: true
  },
  versionCheck: {
    title: "Check MillenniumOS version",
    description: "Check that the MillenniumOS version installed in RRF matches the post-processor version. Undefined behaviour may occur if this check is disabled and the firmware is not compatible with this post-processor.",
    group: "formats",
    scope: "post",
    type: "boolean",
    value: true
  },
  warpSpeedMode: {
    title: "Restore rapid moves at and above the selected height",
    description: "The operation height above which G0 moves will be restored. Only vertical OR lateral moves are considered. None disables warp mode. Retract and Clearance restore rapid moves at and above the relevant height set on the operation. Zero restores all rapid moves at or above Z=0 in the active WCS. BEWARE: Be absolutely certain when using Zero mode that your tool offsets are calculated accurately, as rapid moves back down to Z=0 will not allow any leeway for tool length errors! Additionally, only use Zero if you can guarantee there is nothing above Z=0 that could interfere with rapid moves.",
    group: "formats",
    scope: "post",
    type: "enum",
    values: warpSpeedModeProperty,
    value: warpSpeedMode.NONE
  },
  outputJobSetup: {
    title: "Output job setup commands",
    description: "When enabled, the post-processor will output supplemental commands to make sure the machine is properly configured before starting a job. These commands include homing the machine, probing and zeroing any used WCSs. Individual supplemental commands can be enabled, disabled and configured separately but disabling this allows advanced operators to setup the machine for the job using their own workflow, while still outputting known-good operation gcode from this post.",
    group: "configuration",
    scope: "post",
    type: "boolean",
    value: true
  },
  jobHomeBeforeStart: {
    title: "Home before start",
    description: "When enabled, machine will home in X, Y and Z directions prior to executing any operations.",
    group: "homePositions",
    scope: ["machine","post"],
    type: "boolean",
    value: false
  },
  jobWCSProbeMode: {
    title: "WCS Origin Probing Mode",
    description: "Select how and when to probe and set WCS origins. Selecting 'At Start' will run a probing operation for all used WCS origins before executing any operations in the Program. This is useful if working on multiple objects in the same Program, where each object has its own origin. Selecting 'On Change' will probe each WCS origin just prior to switching into it for the first time. This is useful if you're working on a single object per Program but in multiple planes, where a WCS change can coincide with the part being reoriented manually. Selecting 'None (Expert Mode)' means no automatic WCS origin probing will be output. Either your WCS origins are pre-configured before running this Program, or you have configured Probing operations manually in the program exactly where you need them.",
    group: "probing",
    type: "enum",
    values: wcsProbeModeProperty,
    value: wcsProbeModeProperty[2].id
  },
  vsscEnabled: {
    title: "Enable Variable Spindle Speed Control",
    description: "When enabled, spindle speed is varied between an upper and lower limit surrounding the requested RPM which helps to avoid harmonic resonance between tool and work piece.",
    group: "spindle",
    scope: ["post","operation"],
    type: "boolean",
    value: true
  },
  vsscVariance: {
    title: "Variable Spindle Speed Control Variance (rpm)",
    description: "Total variance in rpm to adjust around the requested spindle speed when VSSC is enabled. A value of 100 will vary the spindle speed from 50rpm below to 50rpm above the requested value.",
    group: "spindle",
    scope: ["post","operation"],
    type: "integer",
    value: 200
  },
  vsscPeriod: {
    title: "Variable Spindle Speed Control Period (ms)",
    description: "Period in milliseconds over which rpm is varied around the requested spindle speed when VSSC is enabled.",
    group: "spindle",
    scope: ["post","operation"],
    type: "integer",
    value: 4000
  },
  lowMemoryMode: {
    title: "Low Memory Mode",
    description: "When enabled, the post-processor will output gcode in a way that minimizes memory usage on the machine controller. Specifically, it will convert arcs and helical moves into a series of linear moves. If you receive 'OutOfMemory' errors on your mainboard then enabling this may help.",
    group: "configuration",
    scope: "post",
    type: "boolean",
    value: true
  }
};

// Configure command formatting functions
// Contrary to what everyone understands an INTEGER to be, Fusion360 CAM believes
// FORMAT_INTEGER means "output whole numbers without a decimal point", _AND_ output
// decimal numbers with a decimal point. The post-processor training guide suggests
// FORMAT_TZS (format trailing zero suppression) is the right format to use, but
// that one outputs everything with a decimal point and without the trailing zeroes.
// I'm not sure what was being smoked that day, but the below type specifications
// output the right decimal codes we need.
var gFmt = createFormat({ prefix: "G", decimals: 1, type: FORMAT_INTEGER }); // Create formatting command for G codes
var mFmt = createFormat({ prefix: "M", decimals: 1, type: FORMAT_INTEGER }); // Create formatting command for M codes
var tFmt = createFormat({ prefix: "T", decimals: 0 }); // Create formatting command for T (tool) codes


// Create formatting output for X, Y and Z axes. Use 3 d.p. for milimeters and 4 for anything else.
// Format radiuses in the same way
var axesFmt   = createFormat({ decimals: (unit == MM ? 3 : 4), type: FORMAT_REAL, minDigitsRight: 1});
var radiusFmt = axesFmt;

// Create formatting output for feed variable.
var feedFmt   = createFormat({decimals:(unit == MM ? 1 : 2), type: FORMAT_REAL, minDigitsRight: 1 });

// Used for integer output - RPM, seconds, tool properties etc
var intFmt = createFormat({ type: FORMAT_INTEGER, decimals: 0 });

// Force output of G, M and T commands when executed
var gCmd = createOutputVariable({ control: CONTROL_FORCE }, gFmt );
var mCmd = createOutputVariable({ control: CONTROL_FORCE }, mFmt );
var tCmd = createOutputVariable({ control: CONTROL_FORCE }, tFmt );

// Output X, Y and Z variables when set
var xVar = createOutputVariable({ prefix: "X" }, axesFmt);
var yVar = createOutputVariable({ prefix: "Y" }, axesFmt);
var zVar = createOutputVariable({ prefix: "Z" }, axesFmt); // TODO: Investigate safe retracts using parking location
var aVar = createOutputVariable({ prefix: "A" }, axesFmt);

// Output Feed variable when set
var fVar = createOutputVariable({ prefix:"F"}, feedFmt);

// Output I, J and K variables (for arc moves)
var iVar = createOutputVariable({ prefix: "I", control: CONTROL_NONZERO }, axesFmt);
var jVar = createOutputVariable({ prefix: "J", control: CONTROL_NONZERO }, axesFmt);
var kVar = createOutputVariable({ prefix: "K", control: CONTROL_NONZERO }, axesFmt);

// Probing variables
var jPVar = createOutputVariable({ prefix: "J", control: CONTROL_NONZERO }, axesFmt);
var kPVar = createOutputVariable({ prefix: "K", control: CONTROL_NONZERO }, axesFmt);
var lPVar = createOutputVariable({ prefix: "L", control: CONTROL_NONZERO }, axesFmt);
var xPVar = createOutputVariable({ prefix: "X" }, axesFmt);
var yPVar = createOutputVariable({ prefix: "Y" }, axesFmt);
var zPVar = createOutputVariable({ prefix: "Z" }, axesFmt);

// Output R (radius) variables
var rVar = createOutputVariable({ prefix: "R", control: CONTROL_NONZERO }, radiusFmt);

// Output RPM whenever set, as we may need to start spindle back up after a tool change.
var sVar = createOutputVariable({ prefix: "S", control: CONTROL_FORCE }, intFmt);

// Output dwell whenever set.
// Note: this uses same prefix as sVar but is passed to G4 rather than M commands.
var dVar = createOutputVariable({ prefix: "S", control: CONTROL_FORCE }, intFmt);

// Define G code constants for non-standard codes.

var G = {
  PARK: 27,
  HOME: 28,
  PROBE_OPERATOR: 6600,
  PROBE_BORE: 6500.1,
  PROBE_BOSS: 6501.1,
  PROBE_RECTANGLE_POCKET: 6502.1,
  PROBE_RECTANGLE_BLOCK: 6503.1,
  PROBE_SINGLE_SURFACE: 6510.1,
  PROBE_REFERENCE_SURFACE: 6511,
  PROBE_VISE_CORNER: 6520.1,
};

// TODO: Add more probing codes

// Define M code constants for non-standard codes.
var M = {
  ADD_TOOL: 4000,
  VERSION_CHECK: 4005,
  ENABLE_ROTATION_COMPENSATION: 5011,
  VSSC_ENABLE: 7000,
  VSSC_DISABLE: 7001,
  SPINDLE_ON_CW: 3.9,
  SPINDLE_ON_CCW: 4.9,
  SPINDLE_OFF: 5.9,
  CALL_MACRO: 98,
  COOLANT_MIST: 7,
  COOLANT_AIR: 7.1,
  COOLANT_FLOOD: 8,
  COOLANT_OFF: 9
};

// Enumerate the operation:tool_coolant options into codes
var COOLANT = {
  disabled: M.COOLANT_OFF,
  flood: M.COOLANT_FLOOD,
  mist: M.COOLANT_MIST,
  air: M.COOLANT_AIR
}

var CYCLE = {
  // Great consistency on the cycle type names here
  DRILLING: 'drilling',
  CHIP_BREAKING: 'chip-breaking',
  COUNTER_BORING: 'counter-boring',
  DEEP_DRILLING: 'deep-drilling',
  BREAK_THROUGH: 'break-through-drilling',
  BORING: 'boring',
  THREAD_MILLING: 'thread-milling',
  PROBING_X: 'probing-x',
  PROBING_Y: 'probing-y',
  PROBING_Z: 'probing-z',
  PROBING_XY_CIRCULAR_BOSS: 'probing-xy-circular-boss',
  PROBING_XY_CIRCULAR_HOLE: 'probing-xy-circular-hole',
  PROBING_XY_RECTANGULAR_BOSS: 'probing-xy-rectangular-boss',
  PROBING_XY_RECTANGULAR_HOLE: 'probing-xy-rectangular-hole',
  PROBING_XY_INNER_CORNER: 'probing-xy-inner-corner',
  PROBING_XY_OUTER_CORNER: 'probing-xy-outer-corner'
};

// Create modal groups
// NOTE: Modal groups do not handle decimal
// gcodes correctly, it looks like they are
// floored and outputted as an integer.
var gCodes = createModalGroup(
  // Only allow the following gcodes to be outputted (we restrict
  // output to gcodes we know are safe).
  { strict: true, force: false },
  [
      [17, 18, 19],                 // Plane codes
      [20, 21],                     // Unit codes
      [53, 54, 55, 56, 57, 58, 59], // WCS codes
      [90, 91, 93, 94],             // Positioning and feed codes
  ],
  gFmt);

// Gcodes which will always be output.
var gCodesF = createModalGroup(
  { strict: true, force: true },
  [
      [0, 1, 2, 3],                               // Motion codes
      [4],                                        // Dwell codes
      [G.PARK, G.HOME],                           // Other positioning codes
      [
        G.PROBE_OPERATOR,
        G.PROBE_BORE,
        G.PROBE_BOSS,
        G.PROBE_RECTANGLE_POCKET,
        G.PROBE_RECTANGLE_BLOCK,
        G.PROBE_SINGLE_SURFACE,
        G.PROBE_REFERENCE_SURFACE,
        G.PROBE_VISE_CORNER,
      ] // Probe codes
  ],
  gFmt);

var mCodes = createModalGroup(
  // Only allow the following mcodes to be outputted.
  { strict: true, force: true },
  [
    [0, 2],                           // Program codes
    [M.ADD_TOOL],                     // Tool data codes
    [M.VERSION_CHECK],                // Version check
    [M.VSSC_ENABLE, M.VSSC_DISABLE],  // VSSC codes
    [M.ENABLE_ROTATION_COMPENSATION]  // Rotation compensation
  ],
  mFmt);


// Called to make sure X/Y/Z variables are output when next called
function resetXYZ() {
  xVar.reset();
  yVar.reset();
  zVar.reset();
};

// Called to make sure X/Y/Z and F variables are output when next called.
function resetAll() {
  resetXYZ();
  fVar.reset();
  gCodes.reset();
}

// Regular expression for safe comment characters
var safeText = /[^0-9a-z\.:,=_\-\s]/gi;

// Write comments with safe punctuation.
function writeComment(text) {
  writeln("(" + text.replace(safeText, "") + ")");
}

// Write formatted gcode block
function writeBlock() {
  var text = formatWords(arguments);
  if(!text) {
    return
  }
  writeWords(text);
}

// Function onOpen. Called at start of each CAM operation
function onOpen() {
  var seenWCS = [];

  // Don't allow use of WCS 0 (machine co-ordinates in RRF) as this probably
  // means no WCS Zero point is set and we'll end up crashing into things.
  if(getNumberOfSections() > 0) {
    for(var i = 0; i < getNumberOfSections(); i++) {
      var wcs = getSection(i).workOffset;
      // Track the WCS we've seen so far
      seenWCS.push(wcs);
    }
  }

  // We don't allow this to be configurable as it makes gcode files
  // impossible to read.
  setWordSeparator(" ");

  // Output header and preamble
  writeComment("Exported by Fusion360");

  var version = "v0.5.0-1-gca8a344-dirty";

  // Write post-processor and generation details.
  writeComment("Post Processor: {desc} by {vendor}, version: {version}".supplant({desc: description, vendor: vendor, version: version }));

  writeComment("Output Time: {date}".supplant({date: new Date().toUTCString()}));
  writeln("");
  writeComment("WARNING: This gcode was generated to target a singular firmware configuration for RRF.");
  writeComment("This firmware implements various safety checks and spindle controls that are assumed by this gcode to exist.");
  writeComment("DO NOT RUN THIS GCODE ON A MACHINE OR FIRMWARE THAT DOES NOT CONTAIN THESE CHECKS!");
  writeComment("You are solely responsible for any injuries or damage caused by not heeding this warning!");
  writeln("");
  writeComment("Begin preamble");
  writeln("");

  if(properties.versionCheck) {
    writeComment("Check MillenniumOS version matches post-processor version");
    writeBlock(mCodes.format(M.VERSION_CHECK), 'V"{version}"'.supplant({version: version}));
    writeln("");
  }

  // Output tool details if enabled and tools are configured
  var tools  = getToolTable();
  var nTools = tools.getNumberOfTools()
  if (properties.outputTools && nTools > 0) {
    writeComment("Pass tool details to firmware");
    for(var i = 0; i < nTools; i++) {
      var tool = tools.getTool(i);
      if(tool.description.length < 1) {
        error("Tool description must not be empty!");
      }
      writeBlock('{cmd} P{index} R{radius} S"{desc}"'.supplant({
        cmd: mCodes.format(M.ADD_TOOL),
        index: intFmt.format(tool.number),
        radius: axesFmt.format(tool.diameter/2),
        desc: tool.description.substring(0, 32),
      }));
    }
    writeln("");
  }

  // Output job setup commands if necessary
  if(getProperty("outputJobSetup")) {
    // If homeBeforeStart enabled, output G.HOME
    if(getProperty("jobHomeBeforeStart")) {
      writeComment("Home before start");
      writeBlock(gCodesF.format(G.HOME));
      writeln("");
    }

    // We trigger a reference surface probe here. If the surface
    // is already probed, this is a no-op.
    writeComment("Probe reference surface if necessary");
    writeBlock(gCodesF.format(G.PROBE_REFERENCE_SURFACE));
    writeln("");

    writeComment("WCS Probing Mode: {mode}".supplant({mode: getProperty("jobWCSProbeMode")}));
    if(getProperty("jobWCSProbeMode") === wcsProbeMode.ATSTART) {
      writeln("")
      for(var i = 0; i < seenWCS.length; i++) {
        var wcs = seenWCS[i];
        writeComment("Probe origin and save in WCS {wcs}".supplant({wcs: wcs}));
        writeBlock(gCodesF.format(G.PROBE_OPERATOR), "W{offset}".supplant({offset: wcs-1}));
        writeln("");
      }
    } else {
      writeln("");
    }
  }

  // Output movement configuration - absolute moves, mm or inches, arcs in X/Y.
  writeComment("Movement Configuration");
  writeBlock(gCodes.format(90));
  switch (unit) {
    case MM:
      writeBlock(gCodes.format(21));
      break;
    case IN:
      error("MillenniumOS does not support gcode output in inches. Please switch your post-processor output to millimeters.");
  }

  // All feeds in mm/min
  writeBlock(gCodes.format(94));

  writeln("");
};

// Track parameter values required for the current operation.
var curOp = {
  ctx: "unknown",
  strat: "unknown",
  comment: "",
  probe_work_offset: 1,
  tool_desc: "unknown",
  clearance: Number.MAX_SAFE_INTEGER,
  retract: Number.MAX_SAFE_INTEGER
};

// Track parameter values containing details about the current tool.
var curTool = {
  number: -1,
  desc: "unknown",
  rpm: 0,
  run_cmd: M.SPINDLE_OFF, // Default to not turning on the spindle
  flutes: 0,
  type: -1,
  length: 0,
  diameter: 0,
  corner_radius: 0,
  coolant: "disabled"
}

// Handle parameters.
function onParameter(param, value) {
  switch(param) {
    // Save operation details
    case 'operation:context':
      curOp['ctx'] = value;
    break
    case 'operation:strategy':
      curOp['strat'] = value;
    break;
    case 'operation-comment':
      curOp['comment'] = value;
    break;
    case 'probe-output-work-offset':
      curOp['probe_work_offset'] = (value > 0) ? value : 1;
    break;
    // Save tool details
    case 'operation:tool_type':
      curTool['type'] = value;
    break;
    case 'operation:tool_number':
      curTool['number'] = value;
    break;
    case 'operation:tool_description':
      curTool['desc'] = value;
    break;
    case 'operation:tool_numberOfFlutes':
      curTool['flutes'] = value;
    break;
    case 'operation:tool_fluteLength':
      curTool['length'] = value;
    break;
    case 'operation:tool_diameter':
      curTool['diameter'] = value;
    break;
    case 'operation:tool_coolant':
      curTool['coolant'] = value;
    break;
    case 'operation:tool_cornerRadius':
      curTool['corner_radius'] = value;
    break;
    case 'operation:tool_spindleSpeed':
      curTool['rpm'] = value;
    break;
    case 'operation:tool_clockwise':
      curTool['run_cmd'] = (value === 1) ? M.SPINDLE_ON_CW : M.SPINDLE_ON_CCW;
    break;

    // Track feed height and clearance height
    case 'operation:zClearance':
      curOp['clearance'] = value;
    break;
    case 'operation:zRetract':
      curOp['retract'] = value;
    break;

    // DEBUG: Uncomment this to write comments for all unhandled parameters.
    // default:
    //   writeComment("{p}: {v}".supplant({p: param, v: value}));
  }
}

// On every Gcode section (generally an operation).
function onSection() {
  // Check if the work coordinate system is changing.
  // It is changing if this is the first section (i.e. it has not been activated yet)
  // or if it is not equal to the WCS in the previous section.
  var wcsChanging = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset);

  // Check if the tool is changing.
  // It is changing if this is the first section (i.e. a tool has not been activated yet)
  // or if it is not equal to the tool used in the previous section.
  var toolChanging = isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);

  var curWorkOffset = currentSection.workOffset;

  if(curWorkOffset > 9) {
    error("Extended Work Co-ordinate Systems above G59.3 are not supported by MillenniumOS!")
  }

  // Work Offset
  if (curWorkOffset < 1) {
    curWorkOffset = 1;
  }

  // Only probe on WCS change if probe mode is set to ONCHANGE
  var doProbe = getProperty("jobWCSProbeMode") === wcsProbeMode.ONCHANGE && !isProbeOperation();

  var workOffsetF = { wcs: curWorkOffset };

  // WCS Gcode is the offset from 54 (first work offset).
  var wcsCode = wcsBase + curWorkOffset;

  // If WCS is changing,
  if(wcsChanging) {
    writeComment("Park ready for WCS change");
    writeBlock(gCodesF.format(G.PARK));
    writeln("");
    writeComment("Switch to WCS {wcs}".supplant(workOffsetF));
    writeBlock(gCodes.format(wcsCode));
    writeln("");
    if(doProbe) {
      writeComment("Probe origin in current WCS");
      writeBlock(gCodesF.format(G.PROBE_OPERATOR));
      writeln("");
    }

    writeComment("Enable rotation compensation if necessary");
    writeBlock(mCodes.format(M.ENABLE_ROTATION_COMPENSATION));
    writeln("");
  }


  // If tool requires changing or wcs was probed
  // We must force a tool change if probe was required
  // because the tool change is what deactivates the
  // touch probe.
  if(toolChanging || (wcsChanging && doProbe)) {
    writeComment("TC: {desc} L={length}".supplant(curTool));

    // Write tool change command.
    writeBlock(tCmd.format(tool.number));

    writeln("");
  }

  var s = sVar.format(curTool['rpm']);

  // Only output VSSC and spindle commands if spindle speed
  // is set, and has changed.
  if(s !== "" && curTool['type'] !== TOOL_PROBE && curTool['rpm'] > 0) {
    if(getProperty("vsscEnabled")) {
      writeComment("Enable Variable Spindle Speed Control");
      writeBlock(mCodes.format(M.VSSC_ENABLE), "P{period} V{variance}".supplant({
        period: getProperty("vsscPeriod"),
        variance: getProperty("vsscVariance")
      }));
      writeln("");
    }

    // If RPM has changed, output updated M3 command
    // We do this regardless of tool-change, because
    // operations may have different RPMs set on the
    // same tool.
    writeComment("Start spindle at requested RPM and wait for it to accelerate");

    // We must use mFmt directly rather than mCodes here
    // because modal groups do not correctly handle
    // decimals.
    writeBlock(mFmt.format(M.SPINDLE_ON_CW), s);
    writeln("");

    if(!(curTool.coolant in COOLANT)) {
      error("Unsupported coolant type '{c}'.".supplant({c: curTool.coolant}));
    }

    var coolant = COOLANT[curTool.coolant];

    // Set to valid coolant option, otherwise set coolant to off.
    if (coolant != COOLANT.disabled) {
      writeComment("Enable {c} Coolant".supplant({c: curTool.coolant.capitalize()}));
      writeBlock(mFmt.format(coolant));
      writeln("");
    }
  }

  // Output operation details after WCS and tool changing.
  writeComment("Begin {c} {s}: {v}".supplant({c: curOp['ctx'], s: curOp['strat'], v: curOp['comment']}));
  writeln("");

  resetAll();

  // Get start position
  var startPos = getFramePosition(currentSection.getInitialPosition());

  // Move laterally from park location to initial positions in X and Y
  writeComment("Move to starting position in X and Y");
  writeBlock(gCodesF.format(0), xVar.format(startPos.x), yVar.format(startPos.y));
  writeln("");

  // Move to initial Z position (usually clearance height)
  writeComment("Move to starting position in Z");
  writeBlock(gCodesF.format(0), zVar.format(startPos.z));
  writeln("");

}

// At the end of every section
function onSectionEnd() {
  // Write a newline to delineate
  writeln("");

  if(getProperty("vsscEnabled")) {
    writeComment("Disable Variable Spindle Speed Control");
    writeBlock(mCodes.format(M.VSSC_DISABLE));
    writeln("");
  }

  if (COOLANT[curTool.coolant] != COOLANT.disabled) {
    writeComment("Disable Coolant");
    writeBlock(mFmt.format(M.COOLANT_OFF));
    writeln("");
  }

  // Reset all variable outputs ready for the next section
  resetAll();
}

// Change sign of value based on
// approach direction.
function approach(sign, value) {
  if(sign == "positive") {
    return value;
  }
  if(sign == "negative") {
    return -value;
  }
  return error("Invalid probing approach.");
}

// Handle probing cycle points
function onProbingCyclePoint(x, y, z, cycle) {
  switch(cycleType) {
    case CYCLE.PROBING_X:
      probeVars.concat([
        gCodesF.format(G.PROBE_SINGLE_SURFACE),
          jPVar.format(x),
          kPVar.format(y),
          lPVar.format(z - cycle.depth),
          xPVar.format(x + approach(cycle.approach1, cycle.probeClearance)),
      ]);
    break;
    case CYCLE.PROBING_Y:
      probeVars.concat([
        gCodesF.format(G.PROBE_SINGLE_SURFACE),
          jPVar.format(x),
          kPVar.format(y),
          lPVar.format(z - cycle.depth),
          yPVar.format(y + approach(cycle.approach1, cycle.probeClearance)),
      ]);
    break;
    case CYCLE.PROBING_Z:
      probeVars.concat([
        gCodesF.format(G.PROBE_SINGLE_SURFACE),
          jPVar.format(x),
          kPVar.format(y),
          lPVar.format(Math.min(z - cycle.depth + cycle.probeClearance, cycle.retract)),
          zPVar.format(z - cycle.depth),
      ]);
    break;
    case CYCLE.PROBING_XY_OUTER_CORNER:
      probeVars.concat([
        gCodesF.format(G.PROBE_OUTER_CORNER),
          jPVar.format(x),
          kPVar.format(y),
          lPVar.format(z - cycle.depth),
          xPVar.format(x + approach(cycle.approach1, cycle.probeClearance)),
          yPVar.format(y + approach(cycle.approach2, cycle.probeClearance)),
      ]);
      // Add H and I variables if probe spacing is defined, which
      // will perform an extra probe along each axis and can calculate
      // the angle of the probed corner.
      if(cycle.probeSpacing !== undefined) {
        probeVars.push("H{xS} I{yS}".supplant({xS: cycle.probeSpacing, yS: cycle.probeSpacing}))
      }
    default:
      error("Unsupported probing cycle type: {type}".supplant({type: cycleType}));
  }

  writeBlock(probeVars);
}

// Handle drilling cycle points
function onDrillingCyclePoint(x, y, z, cycle) {
  repositionToCycleClearance(cycle, x, y, z);
  expandCyclePoint(x, y, z);
}

function onCycle() {
  writeComment("Cycle Type: {type}".supplant({type: cycleType}));
  writeln("");
}

// Called when a cycle point is generated
function onCyclePoint(x, y, z) {
  if(isProbingCycle()) {
    return onProbingCyclePoint(x, y, z, cycle);
  }

  switch(cycleType) {
    case CYCLE.CHIP_BREAKING:
    case CYCLE.DRILLING:
    case CYCLE.COUNTER_BORING:
    case CYCLE.DEEP_DRILLING:
    case CYCLE.BREAK_THROUGH:
    case CYCLE.BORING:
    case CYCLE.THREAD_MILLING:
      return onDrillingCyclePoint(x, y, z, cycle);

    case CYCLE.PROBING_X:
    case CYCLE.PROBING_Y:
    case CYCLE.PROBING_Z:
    case CYCLE.PROBING_XY_OUTER_CORNER:
      return onProbingCyclePoint(x, y, z, cycle);

    default:
      return error("Unsupported cycle type: {type}".supplant({type: cycleType}));
  }
}

// Called when a spindle speed change is requested
function onSpindleSpeed(rpm) {
  writeln("")
  if(rpm > 0) {
    writeComment("Spindle speed changed");
    writeBlock(mFmt.format(M.SPINDLE_ON_CW), sVar.format(rpm));
  }
}

// Called when a rapid linear move is requested
function onRapid(x, y, z, a) {
  var a1 = xVar.format(x);
  var a2 = yVar.format(y);
  var a3 = zVar.format(z);
  var a4 = aVar.format(a);

  // If any co-ordinates are changing, output G0 move.
  if (a1 || a2 || a3 || a4) {
    writeBlock(gCodesF.format(0), a1, a2, a3, a4);
    // Always output feed after rapid moves.
    fVar.reset();
  }
}

// Called when a controlled linear move is requested
function onLinear(x, y, z, a, f) {
  var a1 = xVar.format(x);
  var a2 = yVar.format(y);
  var a3 = zVar.format(z);
  var a4 = aVar.format(a);
  var a5 = fVar.format(f);

  var warpMode = getProperty("warpSpeedMode");
  var warpable = false;
  switch(warpMode) {
    case warpSpeedMode.CLEARANCE:
      warpable = (z >= curOp['clearance']);
    break;
    case warpSpeedMode.RETRACT:
      warpable = (z >= curOp['retract']);
    break;
    case warpSpeedMode.ZERO:
      warpable = (z >= 0);
    break;
    default:
      warpable = false
  }

  // Warp if we can. We will not warp if moving in all 3 axes
  // even if the target is above the warp height, for safety
  // purposes.
  var isHorizontal = (a1 || a2) && !a3;
  var isVertical = !a1 && !a2 && a3;
  if ((isHorizontal || isVertical) && warpable) {
      writeln("");
      writeComment("Warp move");
      writeBlock(gCodesF.format(0), a1, a2, a3, a4);
      fVar.reset();
  // Otherwise output normal linear move
  } else if (a1 || a2 || a3 || a4) {
    writeBlock(gCodesF.format(1), a1, a2, a3, a4, a5);
  // Otherwise output just feed change if necessary
  } else if(a5) {
    // Try not to output feed changes on their own unless
    // the next record is not a motion command.
    if (!getNextRecord().isMotion()) {
      // If next record is not motion, just output feed change
      // on its' own.
      writeBlock(gCodesF.format(1), a5);
    } else {
      fVar.reset();
    }
  }

}

// Generate the correct arc variables based on the selected plane.
function getArcVars(plane, start, cx, cy, cz) {
  // RRF requires arc centers (I, J and K) to be relative
  // so we need to use the start position to calculate
  // the relative distance.

  var b1,b2;

  switch(plane) {
    case PLANE_XY:
      b1 = iVar.format(cx - start.x);
      b2 = jVar.format(cy - start.y);
    break;
    case PLANE_ZX:
      b1 = iVar.format(cx - start.x);
      b2 = kVar.format(cz - start.z);
    break;
    case PLANE_YZ:
      b1 = jVar.format(cy - start.y);
      b2 = kVar.format(cz - start.z);
    break;
  }
  return [b1, b2];
}

// Output the right plane gcode based on the arc plane.
function outputPlaneCommand(plane) {
  var code;
  var planeStr = "";
  switch(plane) {
    case PLANE_XY:
      code = 17;
      planeStr = "XY";
    break;
    case PLANE_ZX:
      code = 18;
      planeStr = "XZ";
    break;
    case PLANE_YZ:
      code = 19;
      planeStr = "YZ";
    break;
    default:
      return;
  }
  var pc = gCodes.format(code);
  if (pc !== "") {
    writeln("");
    writeComment("Switch to {plane} plane for arc moves".supplant({plane: planeStr}));
    writeBlock(pc);
  }
}

// Output 360 degree arc move on given plane.
// Helical full circles are not supported and must be
// linearized (TODO: why? RRF or F360 limitation?),
// so we assume movement only in the arc plane
// which is why we never supply a third axis ("a3").
// The assumption here is that our current location in the
// third axis will not change.
function outputFullCircleCommand(plane, clockwise, cx, cy, cz, f) {
  var a1,a2;
  var start  = getCurrentPosition();
  var b1, b2 = getArcVars(plane, start, cx, cy, cz);

  // Movement is only in arc plane (2 axis).
  switch(plane) {
    case PLANE_XY:
      a1 = xVar.format(start.x);
      a2 = yVar.format(start.y);
    break;
    case PLANE_ZX:
      a1 = xVar.format(start.x);
      a2 = zVar.format(start.z);
    break;
    case PLANE_YZ:
      a1 = yVar.format(start.y);
      a2 = zVar.format(start.z);
    break;
  }

  // Output generated code
  writeBlock(gCodesF.format(clockwise ? 2 : 3), a1, a2, b1, b2, fVar.format(f));
}

// Output a non-full-circle, non-radiused arc. Can contain movement in all 3 axes
// (i.e. helical), so we must supply a third axis (a3).
function outputArcCommand(plane, clockwise, cx, cy, cz, x, y, z, f) {
  var a1 = xVar.format(x);
  var a2 = yVar.format(y);
  var a3 = zVar.format(z);

  var start  = getCurrentPosition();
  var b1, b2 = getArcVars(plane, start, cx, cy, cz);

  writeBlock(gCodesF.format(clockwise ? 2 : 3), a1, a2, a3, b1, b2, fVar.format(f));
}

function outputArcRadiusCommand(clockwise, x, y, z, f) {
  var a1 = xVar.format(x);
  var a2 = yVar.format(y);
  var a3 = zVar.format(z);

  var r = getCircularRadius();
  if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
    r = -r; // Allow up to 359 deg arcs
  }
  writeBlock(gCodesF.format(clockwise ? 2 : 3), a1, a2, a3, rVar.format(r), fVar.format(f));
}

// Called when a circular move is requested.
// Uses the above output* functions to generate the correct G2 or G3 calls
// Linearizes arcs that cannot be processed by RRF.
function onCircular(clockwise, cx, cy, cz, x, y, z, f) {
  var plane = getCircularPlane();

  // Linearize circular moves on non-major planes.
  if(plane === -1) {
    writeln("");
    writeComment("Linearized non-major-plane arc move");
    linearize(tolerance);
  } else if(getProperty("lowMemoryMode")) {
    writeln("");
    writeComment("Linearized circular move - low memory mode enabled");
    linearize(tolerance);
  } else {

    // RRF 3.3 and later: Use of I, J and K parameters depends on
    // the plane selected with G17, G18 or G19. Use I and J for
    // the XY plane (G17), I and K for XZ plane (G18), and J and
    // K for YZ plane (G19).
    outputPlaneCommand(plane);

    // If arc uses radius (R), output usingradius
    if(properties.useRadius) {
      outputArcRadiusCommand(clockwise, x, y, z, f);

    // Otherwise if arc is full circle
    } else if(isFullCircle()) {
      // - and helical, linearize it
      if(isHelical()) {
        writeln("");
        writeComment("Linearized helical full-circle movement");
        linearize(tolerance);
      } else {
        // - and not helical, output circular arc command
        outputFullCircleCommand(plane, clockwise, cx, cy, cz, f);
      }
    // If arc is not full circle
    } else {
      // - output normal arc command.
      outputArcCommand(plane, clockwise, cx, cy, cz, x, y, z, f);
    }
  }
}

function onManualNC(command, value) {
  switch(command) {
    case COMMAND_COMMENT:
      return writeComment(value);

    case COMMAND_DISPLAY_MESSAGE:
      return writeConfirmableDialog(value);

    case COMMAND_PASS_THROUGH:
      return writeBlock(value);

    default:
      return error("Unsupported manual NC command: {command}".supplant({command: command}));
  }
}

function writeConfirmableDialog(text) {
  writeln("");
  writeComment("Output confirmable dialog to operator");
  writeBlock("M3000 R\"Fusion360\" S\"{text}\"".supplant({text: text}));
  writeln("");
}

function onClose() {
  writeComment("Begin postamble");

  // Spindle is assumed to be above work piece at this point.
  // Parking will trigger an M5 within the firmware.
  writeComment("Park");
  writeBlock(gCodesF.format(G.PARK));
  writeln("");

  writeComment("Double-check spindle is stopped!");
  writeBlock(mFmt.format(M.SPINDLE_OFF));
  writeln("");
}

