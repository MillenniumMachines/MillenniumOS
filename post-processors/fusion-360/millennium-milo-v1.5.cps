/**
 * Millenium Machines Milo v1.5 Postprocessor for Fusion360.
 *
 * This postprocessor assumes that most complex functionality like
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

// Set display configuration of Postprocessor as displayed in Fusion360
description = "Milo v1.5";
longDescription = "Millennium Machines Milo v1.5 Post Processor for MillenniumOS.";
vendor = "Millennium Machines";
vendorUrl = "https://www.millenniummachines.com/";
legal = "Copyright (C) 2012-2018 by Autodesk, Inc. 2022-2023 Millenium Machines";

// Postprocessor engine settings
certificationLevel = 2;
minimumRevision = 24000;

// Output file format settings
extension = "gcode";
setCodePage("ascii");

// Machine capabilities
capabilities = CAPABILITY_MILLING;
tolerance    = spatial(0.002, MM);

// Postprocessor settings specific to machine capabilities
minimumChordLength    = spatial(0.1, MM);  // Minimum delta movement when interpolating circular moves
minimumCircularRadius = spatial(0.1, MM);  // Minimum radius of circular moves that can be interpolated
maximumCircularRadius = spatial(1000, MM); // Maximum radius of circular moves that can be interpolated
minimumCircularSweep  = toRad(0.1);        // Minimum angular sweep of circular moves
maximumCircularSweep  = toRad(90);         // Maximum angular sweep of circular moves, set to 90 as we use Radius output for arcs

allowHelicalMoves     = true;              // Output helical moves as arcs
allowSpiralMoves      = false;             // Linearize spirals (circular moves with a different starting and ending radius)
allowedCircularPlanes = undefined;         // Allow arcs on all planes

var wcsProbeMode = {
  'NONE': 0,
  'ATSTART': 1,
  'ONCHANGE': 2
};

var wcsProbeModeNames = {
  [wcsProbeMode['NONE']]: "None (Expert Mode)",
  [wcsProbeMode['ATSTART']]: "At Start",
  [wcsProbeMode['ONCHANGE']]: "On Change"
};

// Property groups for user-configurable properties
var groupDefinitions = {
  spindle: {
    title: "Spindle Setup",
    description: "Spindle configuration",
    collapsed: false,
    order: 20
  }
};

var properties = {
  outputMachine: true,
  outputTools: true,
  outputVersion: true,
  outputJobSetup: true,
  jobHomeBeforeStart: true,
  jobWCSProbeMode: wcsProbeMode.ONCHANGE,
  waitForSpindle: 20,
  variableSpindleSpeedControlEnabled: true,
  variableSpindleSpeedControlPeriod: 2000,
  variableSpindleSpeedControlVariance: 100
};

// Properties configurable by the user when configuring the post-processor
var propertyDefinitions = {
  outputMachine: {
    title: "Output machine details",
    description: "Output machine settings header.",
    group: "configuration",
    type: "boolean",
    values: ["Yes", "No"]
  },
  outputTools: {
    title: "Output tools",
    description: "Output tool details. Disabling this will make tool changes much harder!",
    group: "configuration",
    type: "boolean",
    values: ["Yes", "No"]
  },
  outputVersion: {
    title: "Output version details",
    description: "Output version details header.",
    group: "configuration",
    type: "boolean",
    values: ["Yes", "No"]
  },
  outputJobSetup: {
    title: "Output job setup commands",
    description: "When enabled, the post-processor will output supplemental commands to make sure the machine is properly configured before starting a job. These commands include homing the machine and probing and Zeroing any used WCSs. Individual supplemental commands can be enabled, disabled and configured separately but disabling this allows advanced operators to setup the machine for the job using their own workflow, while still outputting known-good operation gcode from this post.",
    group: "configuration",
    type: "boolean",
    values: ["Yes", "No"]
  },
  jobHomeBeforeStart: {
    title: "Home before start",
    description: "When enabled, machine will home in X, Y and Z directions prior to executing any operations.",
    group: "homePositions",
    scope: "machine",
    type: "boolean",
    values: ["Yes", "No"]
  },
  jobWCSProbeMode: {
    title: "WCS Origin Probing Mode",
    description: "Select how and when to probe and set WCS origins. Selecting 'At Start' will run a probing operation for all used WCS origins before executing any operations in the Program. This is useful if working on multiple objects in the same Program, where each object has its own origin. Selecting 'On Change' will probe each WCS origin just prior to switching into it for the first time. This is useful if you're working on a single object per Program but in multiple planes, where a WCS change can coincide with the part being reoriented manually. Selecting 'None (Expert Mode)' means no automatic WCS origin probing will be output. Either your WCS origins are pre-configured before running this Program, or you have configured Probing operations manually in the program exactly where you need them.",
    group: "probing",
    type: "enum",
    values: [
      { title: wcsProbeModeNames[probeWCSMode['NONE']], value: probeWCSMode['NONE'] },
      { title: wcsProbeModeNames[probeWCSMode['ATSTART']], value: probeWCSMode['ATSTART'] },
      { title: wcsProbeModeNames[probeWCSMode['ONCHANGE']], value: probeWCSMode['ONCHANGE'] }
    ]
  },
  variableSpindleSpeedControlEnabled: {
    title: "Enable Variable Spindle Speed Control",
    description: "When enabled, spindle speed is varied between an upper and lower limit surrounding the requested RPM which helps to avoid harmonic resonance between tool and work piece.",
    group: "spindle",
    scope: "operation",
    type: "boolean",
    values: ["Yes", "No"]
  },
  waitForSpindle: {
    title: "Dwell time in seconds to wait for spindle to reach target RPM",
    description: "When set, machine will wait (dwell) for this number of seconds after starting or stopping the spindle to allow it to accelerate or decelerate to the target speed.",
    group: "spindle",
    scope: "machine",
    type: "integer"
  },
  variableSpindleSpeedControlVariance: {
    title: "Variable Spindle Speed Control Variance",
    description: "Variance above and below target RPM to vary Spindle speed when VSSC is enabled, in RPM.",
    group: "spindle",
    scope: "operation",
    type: "integer"
  },
  variableSpindleSpeedControlPeriod: {
    title: "Variable Spindle Speed Control Period",
    description: "Period over which RPM is varied up and down when VSSC is enabled, in milliseconds.",
    group: "spindle",
    scope: "operation",
    type: "integer"
  }
};

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g,
        function (a, b) {
            var r = o[b];
            return typeof r === 'string' || typeof r === 'number' ? r : a;
        }
    );
};


// Configure command formatting functions
var gFmt = createFormat({ prefix: "G", decimals: 1 }); // Create formatting command for G codes
var mFmt = createFormat({ prefix: "M", decimals: 0 }); // Create formatting command for M codes
var tFmt = createFormat({ prefix: "T", decimals: 0 }); // Create formatting command for T (tool) codes


// Create formatting output for X, Y and Z axes. Use 3 d.p. for milimeters and 4 for anything else.
// Format radiuses in the same way
var axesFmt   = createFormat({ decimals: (unit == MM ? 3 : 4), type: FORMAT_REAL, minDigitsRight: 1});
var radiusFmt = axesFmt;

// Create formatting output for feed variable.
var feedFmt   = createFormat({decimals:(unit == MM ? 1 : 2), type: FORMAT_REAL, minDigitsRight: 1 });

// Create formatting output for spindle RPM, integer only
var rpmFmt = createFormat({ type: FORMAT_INTEGER });

// Create formatting output for seconds, used for delays, integer only.
var secFmt = createFormat({ type: FORMAT_INTEGER });

// Force output of G, M and T commands when executed
var gCmd = createOutputVariable({ control: CONTROL_FORCE }, gFmt );
var mCmd = createOutputVariable({ control: CONTROL_FORCE }, mFmt );
var tCmd = createOutputVariable({ control: CONTROL_FORCE }, tFmt );

// Output X, Y and Z variables when set
var xVar = createOutputVariable({ prefix: "X" }, axesFmt);
var yVar = createOutputVariable({ prefix: "Y" }, axesFmt);
var zVar = createOutputVariable({ prefix: "Z" }, axesFmt); // TODO: Investigate safe retracts using parking location

// Output Feed variable when set
var fVar = createOutputVariable({ prefix:"F" }, feedFmt);

// Output I, J and K variables
var iVar = createOutputVariable({ prefix: "I", control: CONTROL_NONZERO }, axesFmt);
var jVar = createOutputVariable({ prefix: "J", control: CONTROL_NONZERO }, axesFmt);
var kVar = createOutputVariable({ prefix: "K", control: CONTROL_NONZERO }, axesFmt);

// Output R (radius) variables
var rVar = createOutputVariable({ prefix: "R", control: CONTROL_NONZERO }, radiusFmt);

// Output RPM whenever set, as we may need to start spindle back up after a tool change.
var sVar = createOutputVariable({ prefix: "S", control: CONTROL_FORCE }, rpmFmt);

// Output dwell whenever set.
// Note: this uses same prefix as sVar but is passed to G4 rather than M commands.
var dVar = createOutputVariable({ prefix: "S", control: CONTROL_FORCE }, secFmt);

// Define G code constants for non-standard codes.
var G_PARK         = 27;
var G_HOME         = 28;
var G_PROBE_TOOL   = 37;

var G_PROBE_OPERATOR         = 6600;
var G_PROBE_BORE             = 6500;
var G_PROBE_BOSS             = 6501;
var G_PROBE_RECTANGLE_POCKET = 6502;
var G_PROBE_REF_SURFACE      = 6511;
// TODO: Add more probing codes

// Define M code constants for non-standard codes.
var M_ADD_TOOL     = 4000;
var M_VSSC_ENABLE  = 7000;
var M_VSSC_DISABLE = 7001;
var M_PROBE_REMOVE = 7003;

// Define canned-cycle probing identifiers
var CYCLE_PROBING_X                   = 'probing-x';
var CYCLE_PROBING_Y                   = 'probing-y';
var CYCLE_PROBING_Z                   = 'probing-z';
var CYCLE_PROBING_XY_CIRCULAR_BOSS    = 'probing-xy-circular-boss';
var CYCLE_PROBING_XY_CIRCULAR_HOLE    = 'probing-xy-circular-hole';
var CYCLE_PROBING_XY_RECTANGULAR_BOSS = 'probing-xy-rectangular-boss';
var CYCLE_PROBING_XY_RECTANGULAR_HOLE = 'probing-xy-rectangular-hole';
var CYCLE_PROBING_XY_INNER_CORNER     = 'probing-xy-inner-corner';
var CYCLE_PROBING_XY_OUTER_CORNER     = 'probing-xy-outer-corner';

// Create modal groups
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
      [G_PARK, G_HOME],                           // Other positioning codes
      [
        G_PROBE_TOOL,
        G_PROBE_OPERATOR,
        G_PROBE_BORE,
        G_PROBE_BOSS,
        G_PROBE_RECTANGLE_POCKET,
        G_PROBE_REF_SURFACE,
      ] // Probe codes
  ],
  gFmt);

var mCodes = createModalGroup(
  // Only allow the following mcodes to be outputted.
  { strict: true, force: true },
  [
    [0, 2],                          // Program codes
    [3, 4, 5],                       // Spindle codes
    [6],                             // Tool change codes
    [M_ADD_TOOL],                    // Tool data codes
    [M_VSSC_ENABLE, M_VSSC_DISABLE], // VSSC codes
    [M_PROBE_REMOVE]                 // Probe codes
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

// Track current WCS setting
var wcsIndex = 0;

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

// Function onComment. Called for manual NC comment commands
function onComment(text) {
  writeComment(text);
}

// Function onOpen. Called at start of each CAM operation
function onOpen() {
  var seenWCS = [];

  // Don't allow use of WCS 0 (machine co-ordinates in RRF) as this probably
  // means no WCS Zero point is set and we'll end up crashing into things.
  if(getNumberOfSections() > 0) {
    for(var i = 0; i < getNumberOfSections(); i++) {
      var wcs = getSection(i).workOffset;
      if(wcs === 0) {
        error("Operation {index} uses WCS 0 (machine co-ordinates!). Using machine co-ordinates directly increases the chances of unexpected collisions!".supplant({
          index: i
        }));
      }
      // Track the WCS we've seen so far
      seenWCS.push(wcs);
    }
  }

  // We don't allow this to be configurable as it makes gcode files
  // impossible to read.
  setWordSeparator(" ");

  // Output header and preamble
  writeComment("Exported by Fusion360");

  var version = "Unknown";
  if ((typeof getHeaderVersion) == "function" && getHeaderVersion()) {
    version = getHeaderVersion();
  }
  if ((typeof getHeaderDate) == "function" && getHeaderDate()) {
    version += " " + getHeaderDate();
  }

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

  // Output tool details if enabled and tools are configured
  var tools  = getToolTable();
  var nTools = tools.getNumberOfTools()
  if (properties.outputTools && nTools > 0) {
    writeComment("Pass tool details to firmware");
    for(var i = 0; i < nTools; i++) {
      var tool = tools.getTool(i);
      writeBlock('{cmd} I{index} D"{desc} F={f} L={l} CR={cr}"'.supplant({
        cmd: mCodes.format(M_ADD_TOOL),
        index: tool.number,
        desc: tool.description,
        l: axesFmt.format(tool.fluteLength),
        cr: axesFmt.format(tool.cornerRadius),
        f: tool.numberOfFlutes
      }));
    }
    writeln("");
  }

  // Output job setup commands if necessary
  if(properties.outputJobSetup)
    // If homeBeforeStart enabled, output G_HOME
    if(properties.homeBeforeStart) {
      writeComment("Home before start");
      writeBlock(gCodesF.format(G_HOME));
      writeln("");
    }

    if(nTools > 0) {
      writeComment("Probe reference surface prior to tool changes");
      writeBlock(gCodesF.format(G_PROBE_REF_SURFACE));
      writeln("");
    }

    writeComment("WCS Probing Mode: {mode}".supplant({mode: wcsProbeModeNames[properties.jobWCSProbeMode]}));

    if(properties.jobWCSProbeMode === wcsProbeMode.ATSTART) {
      for(var i = 0; i < seenWCS.length; i++) {
        var wcs = seenWCS[i];
        writeComment("Probe origin and save in WCS {wcs}".supplant({wcs: wcs}));
        writeBlock(gCodesF.format(G_PROBE_OPERATOR), "W{wcs}".supplant({wcs: wcs}));
        writeln("");
      }
    }

    if(properties.variableSpindleSpeedControlEnabled) {
      writeComment("Enable Variable Spindle Speed Control");
      writeBlock(mCodes.format(M_VSSC_ENABLE), "P{period} V{variance}".supplant({
        period: properties.variableSpindleSpeedControlPeriod,
        variance: properties.variableSpindleSpeedControlVariance
      }));
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
      writeBlock(gCodes.format(20));
      break;
  }

  // All feeds in mm/min
  writeBlock(gCodes.format(94));

  writeln("");

}

// Track parameter values required for the current operation.
var curOp = {
  ctx: "unknown",
  strat: "unknown",
  comment: "",
  probe_work_offset: 1,
  tool_desc: "unknown"
};

// Track parameter values containing details about the current tool.
var curTool = {
  number: -1,
  desc: "unknown",
  rpm: 0,
  flutes: 0,
  type: -1,
  length: 0,
  diameter: 0,
  corner_radius: 0,
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
    case 'operation:tool_cornerRadius':
      curTool['corner_radius'] = value;
    break;
    case 'operation:tool_spindleSpeed':
      curTool['rpm'] = value;
    break;

    // Generate errors on unsupported parameter values
    case 'operation:isMillingStrategy':
      if(value !== 1) {
        error("Non milling strategies are not supported on Milo!");
      }
    break;
    case 'operation:tool_isMill':
      if(value !== 1) {
        error("Non milling tools are not supported on Milo!");
      }
    break;
    case 'operation:tool_clockwise':
      if(value !== 1) {
        error("Anti-clockwise spindle rotation is not supported on Milo!");
      }
    break;
    case 'operation:isMultiAxisStrategy':
      if(value === 1) {
        error("Multi-axis strategies are not supported on Milo!");
      }
    break;

    // DEBUG: Uncomment this to write comments for all unhandled parameters.
    // default:
    //  writeComment("{p}: {v}".supplant({p: param, v: value}));
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

  var curWCS = currentSection.workOffset;

  if(curWCS > 6) {
    error("Extended Work Co-ordinate Systems (G59.1..9) are not supported on Milo!")
  }



  // If WCS requires changing
  if(wcsChanging) {
    // Only probe on WCS change if probe mode is set to ONCHANGE
    var doProbe = properties.jobWCSProbeMode === wcsProbeMode['ONCHANGE'] && !isProbeOperation();

    var wcsO = { wcs: curWCS };

    // WCS Gcode is the offset from 53 (machine co-ordinates).
    var wcsCode = 53 + curWCS;

    // Only probe if required, prompt operator to remove touch probe
    // before continuing.
    if(doProbe) {
      writeComment("Park ready for WCS change");
      writeBlock(gCodesF.format(G_PARK));
      writeln("");
      writeComment("Probe origin corner and save in WCS {wcs}".supplant(wcsO));
      writeBlock(gCodesF.format(G_PROBE_OPERATOR), "W{wcs}".supplant(wcsO));
      writeln("");
      writeComment("Prompt operator to remove touch probe before continuing");
      writeBlock(mCodes.format(M_PROBE_REMOVE));
      writeln("");
    }
    writeComment("Switch to WCS {wcs}".supplant(wcsO));
    writeBlock(gCodes.format(wcsCode));
    writeln("");
  }

  // If tool requires changing
  if(toolChanging) {
    writeComment("TC: {desc} L={length}".supplant(curTool));

    // Write tool number and M6 command to trigger tool change
    writeBlock(tCmd.format(tool.number), mCodes.format(6));

    writeln("");
  }

  // If RPM has changed, output updated M3 command
  // We do this regardless of tool-change, because
  // operations may have different RPMs set on the
  // same tool.
  var s = sVar.format(curTool['rpm']);
  if(s && curOp['tool_type'] !== TOOL_PROBE) {
    writeComment("Start spindle at requested RPM");
    writeBlock(mCodes.format(3), s);
    if(properties.waitForSpindle > 0) {
      writeln("");
      writeComment("Wait for spindle to reach target RPM");
      writeBlock(gCodesF.format(4), dVar.format(properties.waitForSpindle));
    }
    writeln("");
  }

  // Output operation details after WCS and tool changing.
  writeComment("Begin {c} {s}: {v}".supplant({c: curOp['ctx'], s: curOp['strat'], v: curOp['comment']}));

  resetAll();

  // Get start position
  var startPos = getFramePosition(currentSection.getInitialPosition());

  // Move to Z position first
  writeComment("Move to starting position in Z");
  writeBlock(gCodesF.format(0), zVar.format(startPos.z));

  // Then move to X and Y positions
  writeComment("Move to starting position in X and Y");
  writeBlock(gCodesF.format(0), xVar.format(startPos.x), yVar.format(startPos.y));
}

// At the end of every section
function onSectionEnd() {
  if(isProbeOperation()) {
    writeBlock(gCodesF.format(M_PROBE_REMOVE));
  }

  // Reset all variable outputs ready for the next section
  resetAll();
  // Write a newline to delineate
  writeln("");
}

function onCyclePoint() {
  switch(cycleType) {
    case CYCLE_PROBING_X:
    case CYCLE_PROBING_Y:
    case CYCLE_PROBING_Z:
    case CYCLE_PROBING_XY_CIRCULAR_BOSS:
    case CYCLE_PROBING_XY_CIRCULAR_HOLE:
    case CYCLE_PROBING_XY_RECTANGULAR_BOSS:
    case CYCLE_PROBING_XY_RECTANGULAR_HOLE:
    case CYCLE_PROBING_XY_INNER_CORNER:
    case CYCLE_PROBING_XY_OUTER_CORNER:
    default:
      error("Unsupported probing cycle type: {type}".supplant({type: cycleType}));
  }
}

// Called when a spindle speed change is requested
// function onSpindleSpeed(rpm) {
  // writeComment("Spindle speed changed");
  // writeBlock(mCodes.format(3), sVar.format(rpm));
// }

// Called when a rapid linear move is requested
function onRapid(x, y, z) {
  var a1 = xVar.format(x);
  var a2 = yVar.format(y);
  var a3 = zVar.format(z);

  // If any co-ordinates are changing, output G0 move.
  if (a1 || a2 || a3) {
    writeBlock(gCodesF.format(0), a1, a2, a3);
    // Always output feed after rapid moves.
    fVar.reset();
  }
}

// Called when a controlled linear move is requested
function onLinear(x, y, z, f) {
  var a1 = xVar.format(x);
  var a2 = yVar.format(y);
  var a3 = zVar.format(z);
  var a4 = fVar.format(f);

  // If any co-ordinates are changing, output G1 move.
  if (a1 || a2 || a3) {
    writeBlock(gCodesF.format(1), a1, a2, a3, a4);
  } else if(a4) {
    // Try not to output feed changes on their own unless
    // the next record is not a motion command.
    if (!getNextRecord().isMotion()) {
      // If next record is not motion, just output feed change
      // on its' own.
      writeBlock(gCodesF.format(1), a4);
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
  switch(plane) {
    case PLANE_XY:
      code = 17;
    break;
    case PLANE_ZX:
      code = 18;
    break;
    case PLANE_YZ:
      code = 19;
    break;
    default:
      return;
  }
  writeBlock(gCodes.format(code));
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
    writeComment("Linearized non-major-plane arc move");
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

function onClose() {
  writeComment("Begin postamble");

  // Spindle is assumed to be above work piece at this point.
  // Parking will trigger an M5 within the firmware.
  writeComment("Park at user-defined location");
  writeBlock(gCodesF.format(G_PARK));
  writeln("");

  if(properties.variableSpindleSpeedControlEnabled) {
    writeComment("Disable Variable Spindle Speed Control");
    writeBlock(mCodes.format(M_VSSC_DISABLE));
    writeln("");
  }

  writeComment("Double-check spindle is stopped!");
  writeBlock(mCodes.format(5));
  writeln("");
  writeComment("End Program");
  writeBlock(mCodes.format(0));
}