# -*- coding: utf-8 -*-
# Millenium Machines Milo v1.5 Postprocessor for FreeCAD.
#
# Copyright (C)2022-2023 Millenium Machines
#
# This postprocessor assumes that most complex functionality like
# tool changes and work coordinate setting is handled in the machine firmware.
#
# Calls in to these systems should be a single macro call, preferably using a custom
# gcode rather than macro filename, and how the gcode handles the task in question
# (e.g. tool length calculation being automatic or manual) is a concern for the
# firmware, _not_ this post-processor.
#
# As such, it is a very simple post-processor and only supports 3 axis and one
# spindle. It will NOT output any gcode that we are not 100% certain
# will be safe, based on the following assumptions:
#
# - Your G27 (Park) macro raises Z away from the work piece _before_ running M5.
# - It is the responsibility of your macros to run M5 where needed!
# - It is the responsibility of your macros and firmware to run any safety checks.

import sys
import pprint
import argparse
import shlex
import re
from enum import StrEnum, Flag, auto
from contextlib import contextmanager
import FreeCAD
from FreeCAD import Units
import Path
import Path.Base.Util as PathUtil
import Path.Post.Utils as PostUtils

from datetime import datetime, timezone

class RELEASE:
    VERSION = "%%MOS_VERSION%%"
    VENDOR  = "Millennium Machines"

class PROBE:
    AT_START = 'AT_START'
    ON_CHANGE = 'ON_CHANGE'
    NONE = 'NONE'

class GCODES:
    # Define G code constants for non-standard or regularly used gcodes.
    DWELL                   = 4
    PARK                    = 27
    HOME                    = 28
    PROBE_OPERATOR          = 6600
    PROBE_BORE              = 6500.1
    PROBE_BOSS              = 6501.1
    PROBE_RECTANGLE_POCKET  = 6502.1
    PROBE_RECTANGLE_BLOCK   = 6503.1
    PROBE_SINGLE_SURFACE    = 6510.1
    PROBE_REFERENCE_SURFACE = 6511
    PROBE_VISE_CORNER       = 6520.1

class MCODES:
    # Define M code constants for non-standard or regularly used mcodes.
    CALL_MACRO   = 98
    ADD_TOOL     = 4000
    VSSC_ENABLE  = 7000
    VSSC_DISABLE = 7001
    SHOW_DIALOG  = 3000

# Define format strings for variable and command types
class FORMATS:
    CMD   = '{:0.3f}'
    AXES  = '{:0.3f}'
    TOOLS = '{:0.0f}'
    RPM   = '{:0.0f}'
    STR   = '"{!s}"'
    WCS   = '{:0.0f}'
    FEED  = '{:0.3f}'

# FreeCAD Unit Value Types
# Values will be converted _to_ these
# formats for output.
class UNITS:
    FEED   = 'mm/min'
    LENGTH = 'mm'

# Well-known arguments
# Used to reference arg values for
# additional processing
class ARGS:
    Z    = 'Z'
    FEED = 'F'
    TOOL = 'T'
    RPM  = 'S'

# Define Output control flags
class Control(Flag):
    NONE    = 0
    FORCE   = auto()
    STRICT  = auto()
    NONZERO = auto()

# User-configurable arguments.
parser = argparse.ArgumentParser(prog="MillenniumOS {}".format(RELEASE.VERSION),
    description="MillenniumOS {} Post Processor for FreeCAD".format(RELEASE.VERSION))

parser.add_argument('--show-editor', action=argparse.BooleanOptionalAction, default=True,
    help="Show Gcode in FreeCAD Editor before saving to file.")

parser.add_argument("--output-job-setup", action=argparse.BooleanOptionalAction, default=True,
    help="""
    When enabled, the post-processor will output supplemental commands to make sure the machine
    is properly configured before starting a job. These commands include homing the machine,
    probing and zeroing any used WCSs. Individual supplemental commands can be enabled,
    disabled and configured separately but disabling this allows advanced operators to
    setup the machine for the job using their own workflow, while still outputting
    known-good operation gcode from this post.
    """)

parser.add_argument('--output-machine', action=argparse.BooleanOptionalAction, default=True,
    help="Output machine settings header.")

parser.add_argument('--output-version', action=argparse.BooleanOptionalAction, default=True,
    help="Output version details header.")

parser.add_argument('--output-tools', action=argparse.BooleanOptionalAction, default=True,
    help="Output tool details. Disabling this will make tool changes much harder!")

parser.add_argument('--home-before-start', action=argparse.BooleanOptionalAction, default=True,
    help="When enabled, machine will home in X, Y and Z directions prior to executing any operations.")

probe_mode = parser.add_mutually_exclusive_group(required=False)
probe_mode.add_argument('--probe-at-start', dest='probe_mode', action='store_const', const=PROBE.AT_START,
    help="When enabled, MillenniumOS will probe a work-piece in each used WCS prior to executing any operations.")

probe_mode.add_argument('--probe-on-change', dest='probe_mode', action='store_const', const=PROBE.ON_CHANGE,
    help="When enabled, MillenniumOS will probe a work-piece just prior to switching into each used WCS.")

probe_mode.add_argument('--no-probe', dest='probe_mode', action='store_const', default=PROBE.NONE)

parser.add_argument(
    "--vssc-period",
    type=int,
    default=4000,
    help="Period over which RPM is varied up and down when VSSC is enabled, in milliseconds."
)
parser.add_argument(
    "--vssc-variance",
    type=int,
    default=200,
    help="Variance around target RPM to vary Spindle speed when VSSC is enabled, in RPM."
)
parser.add_argument('--vssc', action=argparse.BooleanOptionalAction, default=True,
    help="""
    When enabled, spindle speed is varied between an upper and lower limit surrounding the requested RPM
    which helps to avoid harmonic resonance between tool and work piece.
    """)


# RRF Strings are not allowed to contain certain characters and
# quotes must be doubled up.
def rrf_safe_string(s):
    return re.sub(r'([^"0-9a-z\.:,=_\-\s])', "", s, flags=re.IGNORECASE).replace('"', '""')

# Define output class. This is used to output both
# commands and their nested variables. Output() instances
# can be nested into other output instances inside the 'vars'
# argument.
class Output:
    def __init__(self, typ=None, fmt='{!s}', prefix=None, ctrl=Control.NONE, vars = None):
        # Take input settings and assign to instance vars
        # if set.
        if fmt is not None:
            self.fmt = fmt
        if prefix is not None:
            self.prefixStr = prefix

        self.typ = typ

        self.varFormats = {}

        if vars is not None:
            for v in vars:
                prefix = v.prefix()
                # We allow multiple outputs for the same prefix. This is
                # to account for commands that use the same prefix for
                # arguments that require a different format (e.g. integer
                # and string).
                if prefix in self.varFormats:
                    self.varFormats[prefix].append(v)
                else:
                    self.varFormats[prefix] = [v,]

        self.ctrl = ctrl
        self.lastVars = ()
        self.lastCode = None

    # Force output of matching prefixes on
    # next command.
    def reset(self, prefixes):
        for prefix in prefixes:
            if prefix in self.varFormats:
                # Reset all Outputs for the matching prefix
                for v in self.varFormats[prefix]:
                    v.reset([prefix,])

            if self.prefix() == prefix:
                self.lastCode = None
                self.lastVars = None

    # Return the current prefix string
    def prefix(self):
        return self.prefixStr

    # Format the given arguments
    def format(self, *args, **kwargs):
        ctrl = kwargs.pop('ctrl', self.ctrl)

        # We can only format when receiving a single argument.
        if self.typ is not None and not isinstance(args[0], self.typ):
            return None

        try:
            out = self.fmt.format(*args, **kwargs)
        except Exception as e:
            raise ValueError("Error formatting output for {} ({}): {}".format(args, kwargs, e))

        # This is crap. There's no way to remove
        # trailing zeroes from a formatted float
        # so we just strip them manually if a decimal
        # separator exists in the string.
        if '.' in out:
            out = out.rstrip('0').rstrip('.')

        # This is also crap, but with inexact
        # floats we might end up with negative
        # zero after formatting, so we need to
        # fix before output.
        if out == '-0':
            out = '0'

        if out == '0' and Control.NONZERO in ctrl:
            return None

        return self.prefix() + out

    # When called, process the code and arguments
    # and output if necessary
    def __call__(self, code, **kwargs):
        ctrl = kwargs.pop('ctrl', self.ctrl)

        frozenvars = (code, frozenset(kwargs.items()))

        # If code and args are the same as last then suppress if
        # force is false.
        if frozenvars == self.lastVars and not (Control.FORCE in ctrl):
            return (None, None)

        self.lastVars = frozenvars


        # If code has changed or force is enabled, output
        # the code.
        outCode = None
        if code != self.lastCode or Control.FORCE in ctrl:
            outCode = self.format(code, ctrl=ctrl)
            if outCode is None:
                return (None, None)
            self.lastCode = code

        # Parse args. We do this regardless of if the code
        # is output because arguments sent on new lines are
        # treated as successive calls to the last G or M
        # code.
        outCmd     = [outCode] if outCode else []
        outChanged = {}

        for k, v in kwargs.items():
            if k in self.varFormats:
                for o in self.varFormats[k]:
                    argOut, _ = o(v)
                    if argOut is not None:
                        outCmd.append(''.join(argOut[0]))
                        # Store index in cmd list of changed key
                        # Necessary because we don't always output
                        # the command itself.
                        outChanged[k] = len(outCmd)-1

                        # Exit once we've outputted a value.
                        # This is only necessary when we have
                        # multiple Outputs for the same prefix.
                        break

            # If strict is not set, output arg key and value
            # in their string formats.
            elif not Control.STRICT in ctrl:
                outCmd.append('{!s}{!s}'.format(k, v))
                outChanged[k] = len(outCmd)-1

        # If the command had arguments but none have changed
        # then do not output the command at all.
        if kwargs and not outChanged:
            return (None, None)

        return (outCmd, outChanged)

# Define post-processor sections
class Section(StrEnum):
    PRE  = auto()
    RUN  = auto()
    POST = auto()

# Implements a generalised post-processor
class PostProcessor:
    name      = "FreeCAD Post-Processor"
    vendor    = "Unknown"


    def __init__(self, name=None, vendor=None, args={}):
        if name is not None:
            self.name = name
        if vendor is not None:
            self.vendor = vendor

        # Set args
        self.args  = args

        # Set default instance vars
        self.tools = {}

        setattr(self, Section.RUN, [])
        setattr(self, Section.PRE, [])
        setattr(self, Section.POST, [])

        # Set default section
        self.oldSection = Section.RUN
        self.curSection = Section.RUN

        # Switch to PRE section
        with self.Section(Section.PRE):
            self.comment('Exported by FreeCAD')
            self.comment('Post Processor: {} by {}'.format(self.name, self.vendor))
            self.comment('Output Time: {}'.format(datetime.now(timezone.utc)))
            self.brk()

    @contextmanager
    def Section(self, section):
        self.oldSection = self.curSection
        self.curSection = section
        try:
            yield
        finally:
            self.curSection = self.oldSection
            self.oldSection = Section.RUN

    def parse(self, objects, skip_inactive=True):
        with self.Section(Section.RUN):
            for o in objects:
                # Recurse over compound objects
                if hasattr(o, 'Group'):
                    for p in o.Group:
                        self.parse(p, skip_inactive=False)

                # Skip non-path objects
                if not hasattr(o, 'Path'):
                    continue

                # Skip inactive operations
                if skip_inactive and PathUtil.opProperty(o, 'Active') is False:
                    continue
                self._parseobj(o)

    # Default object parsing just outputs a 'begin operation'
    # comment and triggers parsing of each command
    def _parseobj(self, obj):
        # Save details about tools used
        tc = PathUtil.toolControllerForOp(obj)
        if tc:
            radius = float(tc.Tool.Diameter.getValueAs(UNITS.LENGTH))/2

            # Corner radius is a pain here because there's no
            # obvious concept of a corner radius in FreeCAD.
            # We can calculate it for the bit types we know are
            # rounded, bullnose and ballnose.
            cr = 0

            # A bull nose bit has a flat radius. The corner radius
            # is the difference between the radius and the flat radius.
            if tc.Tool.ShapeName == "bullnose":
                cr = radius - float(tc.Tool.FlatRadius.getValueAs(UNITS.LENGTH))

            # A ball nose bit is rounded all the way to the centre of
            # the bit. The corner radius is the radius of the bit.
            elif tc.Tool.ShapeName == "ballnose":
                cr = radius

            tool_params = {
                "flutes": tc.Tool.Flutes,
                "radius": radius,
                "tool_length": float(tc.Tool.Length.getValueAs(UNITS.LENGTH)),
                "flute_length": float(tc.Tool.CuttingEdgeHeight.getValueAs(UNITS.LENGTH)),
                "corner_radius": cr
            }
            self.add_tool(tc.ToolNumber, tc.Tool.Label, tool_params)


        for c in obj.Path.Commands:
            self._parsecmd(c)

    # Default parameter parsing just outputs a key value pair
    # and will only accept numeric arguments.
    def _parseparam(self, key, value):
        # TODO: Check if number.
        return '{}{:0.3f}'.format(key, value)

    # Default operation parsing just outputs operation name
    # and arguments without any processing.
    def _parsecmd(self, cmd):
        params = [cmd.Name, ]
        for pkey, pval in cmd.Parameters.items():
            param = self._parseparam(pkey, pval)
            if param:
                params.append(param)
        self.cmd(' '.join(params))

    # Add tool index, description pair to tool info
    def add_tool(self, index, name, params):
        if index in self.tools and name != self.tools[index]['name']:
            raise ValueError("Duplicate tool index {} with different descriptions!".format(index))

        self.tools[index] = {"name": name, "params": params}

    # Return tool info
    def toolinfo(self):
        return self.tools

    # Output a comment to the active section
    def comment(self, msg):
        a = getattr(self, self.curSection)
        a.append('({})'.format(msg))

    # Output a command to the active section
    def cmd(self, cmd):
        if cmd is not None:
            a = getattr(self, self.curSection)
            a.append(cmd)

    # Output a break to the active section
    def brk(self):
        a = getattr(self, self.curSection)
        a.append('')

    # Concat and output the sections
    def output(self):
        out = getattr(self, Section.PRE)
        out.extend(getattr(self, Section.RUN))
        out.extend(getattr(self, Section.POST))
        return '\n'.join(out)

class MillenniumOSPostProcessor(PostProcessor):
    _RAPID_MOVES           = [0]
    _LINEAR_MOVES          = [0, 1]
    _ARC_MOVES             = [2, 3]
    _SPINDLE_ACTIONS_START = [3, 4]
    _SPINDLE_ACTIONS_STOP  = [5]
    _SPINDLE_WAIT_SUFFIX   = .9
    _TOOL_CHANGES          = [6]
    _WCS_CHANGES           = [54, 55, 56, 57, 58, 59, 59.1, 59.2, 59.3]

    # Define command output formatters
    _G   = Output(fmt=FORMATS.CMD, prefix='G', vars = [
            Output(prefix='X', fmt=FORMATS.AXES),
            Output(prefix='Y', fmt=FORMATS.AXES),
            Output(prefix='Z', fmt=FORMATS.AXES),
            Output(prefix='I', fmt=FORMATS.AXES, ctrl=Control.NONZERO),
            Output(prefix='J', fmt=FORMATS.AXES, ctrl=Control.NONZERO),
            Output(prefix='K', fmt=FORMATS.AXES, ctrl=Control.NONZERO),
            Output(prefix='F', fmt=FORMATS.FEED, ctrl=Control.NONZERO),
            Output(prefix='R', fmt=FORMATS.STR),
            Output(prefix='W', fmt=FORMATS.WCS)
        ], ctrl=Control.FORCE)

    _M   = Output(fmt=FORMATS.CMD, prefix='M', vars = [
            Output(prefix='I', ctrl=Control.FORCE),
            Output(prefix='P', typ=str, fmt=FORMATS.STR, ctrl=Control.FORCE),
            Output(prefix='P', fmt=FORMATS.TOOLS, ctrl=Control.FORCE),
            Output(prefix='R', typ=str, fmt=FORMATS.STR, ctrl=Control.FORCE),
            Output(prefix='R', fmt=FORMATS.AXES, ctrl=Control.FORCE),
            Output(prefix='T', fmt=FORMATS.TOOLS, ctrl=Control.FORCE),
            Output(prefix='S', typ=str, fmt=FORMATS.STR, ctrl=Control.FORCE),
            # This acts as default output for S if it does not match the
            # type specified above.
            Output(prefix='S', fmt=FORMATS.RPM, ctrl=Control.FORCE)
        ], ctrl=Control.FORCE)

    _T   = Output(fmt=FORMATS.CMD, prefix='T', ctrl=Control.FORCE)

    def __init__(self, args={}):
        post_name = "MillenniumOS {}".format(RELEASE.VERSION)

        super().__init__(post_name, vendor=RELEASE.VENDOR, args=args)
        self._MOVES           = self._LINEAR_MOVES + self._ARC_MOVES
        self._SPINDLE_ACTIONS = self._SPINDLE_ACTIONS_START + self._SPINDLE_ACTIONS_STOP
        self.active_wcs  = False
        self.used_wcs    = []

        with self.Section(Section.PRE):
            # Warn operator
            self.comment("WARNING: This gcode was generated to target a singular firmware configuration for RRF.")
            self.comment("This firmware implements various safety checks and spindle controls that are assumed by this gcode to exist.")
            self.comment("DO NOT RUN THIS GCODE ON A MACHINE OR FIRMWARE THAT DOES NOT CONTAIN THESE CHECKS!")
            self.comment("You are solely responsible for any injuries or damage caused by not heeding this warning!")
            self.brk()

    def _forceFeed(self):
        self._G.reset([ARGS.FEED,])

    def _forceTool(self):
        self._T.reset([ARGS.TOOL,])

    def _forceSpindle(self):
        self._M.reset([ARGS.RPM,])

    def T(self, code):
        cmd, _ = self._T(code)
        if not cmd:
            return None
        return self.cmd(' '.join(cmd))

    def G(self, code, **params):
        # Parse and format the command into a list
        cmd, changed = self._G(code, **params)
        if not cmd:
            return None

        # Reset tool RPM on park
        if code == GCODES.PARK:
            self._forceTool()
            self._forceFeed()
            self._forceSpindle()

        # If WCS is changing
        if code in self._WCS_CHANGES:
            wcsOffset = int(code - (self._WCS_CHANGES[0]-1))

            self.used_wcs.append(wcsOffset)

            if self.active_wcs:
                self.comment("Park ready for WCS change")
                self.G(GCODES.PARK)
                self.brk()

            # Only probe inline if probe_on_change is set
            if self.args.probe_mode == PROBE.ON_CHANGE:
                self.probe(wcsOffset)

            self.comment("Switch to WCS {}".format(wcsOffset))
            self.active_wcs = True

        if ARGS.FEED in changed:
            # But the code is a move with only a feed arg
            # Then do not output the command at all and
            # make sure it is outputted with the next command
            if code in self._MOVES and len(changed) == 1:
                self._forceFeed()
                return None
            # And command is a rapid move
            if code in self._RAPID_MOVES:
                # Then ignore the feed arg
                # as rapid moves follow machine limits
                del cmd[changed[ARGS.FEED]]
                # Make sure feed is output by the next
                # non-rapid move.
                self._forceFeed()

        if code in self._MOVES and not changed:
            return

        return self.cmd(' '.join(cmd))


    def M(self, code, **params):
        # If code is a tool change, send the T command
        # and return so the M6 is not output.
        if ARGS.TOOL in params and code in self._TOOL_CHANGES:
            self.T(params[ARGS.TOOL])
            self.brk()
            return None

        if ARGS.RPM in params and code in self._SPINDLE_ACTIONS_START:
            self.comment("Start spindle at requested RPM and wait for it to accelerate")

        # Use M98 to call the M3.9 macro, as there is currently an RRF bug that
        # prevents delays from running in macros called directly.
        # More info here: https://forum.duet3d.com/topic/35300/odd-g4-behaviour-from-macro-called-from-sd-file/13?_=1711622479937
        # NOTE: The P parameter conflicts between M98 and M3, so
        # using this approach we _cannot_ target a specific spindle.
        # We don't do that anyway, because we select a tool before
        # setting the spindle speed, but it's worth noting - if there
        # is no tool selected, then this command will return an error.
        if code in self._SPINDLE_ACTIONS:
            macro = "M{}.g".format(code + self._SPINDLE_WAIT_SUFFIX)
            code = MCODES.CALL_MACRO
            params['P'] = macro

        # Call our suffixed spindle control codes
        if code in self._SPINDLE_ACTIONS:
            code += self._SPINDLE_WAIT_SUFFIX

        cmd, args = self._M(code, **params)
        if not cmd:
            return None

        self.cmd(' '.join(cmd))

    def probe(self, wcsOffset):
        self.comment("Probe origin and save in WCS {}".format(wcsOffset))
        self.G(GCODES.PROBE_OPERATOR, W=wcsOffset)
        self.brk()

    def _parseobj(self, obj):
        self.brk()

        # Call parent object parsing method
        if hasattr(obj, 'Proxy'):
            proxy_type = type(obj.Proxy).__name__

            match proxy_type:
                case 'Comment':
                    self.comment("Output confirmable dialog to operator")
                    self.M(MCODES.SHOW_DIALOG, R="FreeCAD", S=obj.Comment)
                    return
                case 'Fixture':
                    pass
                case 'ToolController':
                    self.comment('TC: {}'.format(obj.Tool.Label))
                case _:
                    self.comment('Begin Operation: {}'.format(obj.Label))

        super()._parseobj(obj)


    def _parsecmd(self, cmd):
        ctype = cmd.Name[0].upper()

        # FreeCAD intersperses internal comments with
        # commands so we have to handle these as well.
        # For the moment, just skip.
        if ctype == '(':
            return

        # We convert to float since some commands can have
        # extended (decimal) values
        code = float(cmd.Name[1:])

        params = {}

        for pkey, pvalue in cmd.Parameters.items():
            v = self._parseparam(code, pkey, pvalue)
            if v:
                params[pkey] = v

        match ctype:
            case 'G':
                self.G(code, **params)
            case 'M':
                self.M(code, **params)
            case _:
                raise ValueError("Unknown command type {}".format(cmd.Name))

    # Convert necessary parameters based on FreeCAD units.
    def _parseparam(self, code, key, value):
        match key:
            # Convert FreeCAD feed-rate to machine feed rate
            # Store as an integer. Point something RPM is not necessary,
            # and if we store these as floats then we have to deal with
            # floating point errors during comparison.
            case ARGS.FEED:
                rate = Units.Quantity(value, FreeCAD.Units.Velocity)
                return int(rate.getValueAs(UNITS.FEED))
            # Convert all other floats to machine lengths
            case float():
                val = Units.Quantity(value, FreeCAD.Units.Length)
                return float(val.getValueAs(UNITS.LENGTH))
            # Return all other values as-is (likely strings)
            case _:
                return value

    def rapid(self, x, y, z):
        return self.G(0, X=x, Y=y, Z=z, ctrl=Control.FORCE)

    def linear(self, x, y, z, f):
        return self.G(1, X=x, Y=y, Z=z, F=f, ctrl=Control.FORCE)

    def output(self):
        with self.Section(Section.PRE):
            self.comment("Begin preamble")

            # Parsing must be completed to enumerate all tools.
            tools = self.toolinfo()

            # Output tool details if enabled and tools are configured
            if self.args.output_tools and tools:
                self.brk()
                self.comment("Pass tool details to firmware")
                # Output tool info
                for index, tool in tools.items():
                    tool_desc = ' '.join([tool['name'], "F={flutes} L={flute_length} CR={corner_radius}".format(**tool['params'])])
                    self.M(MCODES.ADD_TOOL, P=index, R=tool['params']['radius'], S=rrf_safe_string(tool_desc), ctrl=Control.FORCE)
                self.brk()

            # Output job setup commands if necessary
            if self.args.output_job_setup:
                if self.args.home_before_start:
                    self.comment("Home before start")
                    self.G(GCODES.HOME)
                    self.brk()

                self.comment("Probe reference surface if necessary")
                self.G(GCODES.PROBE_REFERENCE_SURFACE)
                self.brk()

                # Output probe commands if probe method is AT_START
                self.comment("WCS Probing Mode: {}".format(self.args.probe_mode));
                self.brk()
                if self.args.probe_mode == PROBE.AT_START:
                    for wcs in self.used_wcs:
                        self.probe(wcs)

            self.comment("Movement configuration")
            self.G(90) # Absolute moves
            self.G(21) # All units are millimeters
            self.G(94) # Feeds are per-minute
            self.brk()

            if self.args.vssc:
                self.comment("Enable Variable Spindle Speed Control")
                self.M(MCODES.VSSC_ENABLE, P=self.args.vssc_period, V=self.args.vssc_variance)

        # Switch to post to output ending commands
        with self.Section(Section.POST):
            self.brk()
            self.comment("Begin postamble")
            self.brk()
            self.comment("Park at user-defined location")
            self.G(GCODES.PARK)
            self.brk()

            if self.args.vssc:
                self.comment("Disable Variable Spindle Speed Control")
                self.M(MCODES.VSSC_DISABLE)
                self.brk()

            self.comment("Double-check spindle is stopped!")
            self.M(self._SPINDLE_ACTIONS_STOP[0])

        return super().output()

# Parse and export the CAM objects.
def export(objectslist, filename, argstring):
    try:
        args = parser.parse_args(shlex.split(argstring))
    except Exception as e:
        import pprint
        pprint.pprint(e)
        sys.exit(1)

    # Instantiate the Milo post-processor
    pp = MillenniumOSPostProcessor(args=args)

    pp.parse(objectslist)

    # Generate the output gcode
    out = pp.output()

    # If GUI requested, open editor window
    if FreeCAD.GuiUp and args.show_editor:
        out = PostUtils.editor(out)

    with open(filename, "w") as f:
        f.write(out)