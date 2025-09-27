# -*- coding: utf-8 -*-
# MillenniumOS v0.5.0-1-gca8a344-dirty Postprocessor for FreeCAD.
#
# Copyright (C)2022-2024 Millennium Machines
#
# This post-processor assumes that most complex functionality like
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
import argparse
import shlex
import re
from enum import Flag, auto

if sys.version_info < (3, 11):
    from enum import Enum
    class StrEnum(str, Enum):
        pass
else:
    from enum import StrEnum, auto

from contextlib import contextmanager
import FreeCAD
from FreeCAD import Units
import Path.Base.Util as PathUtil
import Path.Post.Utils as PostUtils
import PathScripts.PathUtils as PathUtils

from datetime import datetime, timezone

class RELEASE:
    VERSION = "v0.5.0-1-gca8a344-dirty"
    VENDOR  = "Millennium Machines"

class PROBE:
    AT_START = 'AT_START'
    ON_CHANGE = 'ON_CHANGE'
    NONE = 'NONE'

class GCODES:
    RAPID                   = 0
    LINEAR                  = 1
    ARC_CW                  = 2
    ARC_CCW                 = 3
    DWELL                   = 4
    ABSOLUTE                = 90
    RELATIVE                = 91
    INCHES                  = 20
    MILLIMETERS             = 21
    FEED_PER_MIN            = 94

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
    CALL_MACRO                   = 98
    ADD_TOOL                     = 4000
    VERSION_CHECK                = 4005
    ENABLE_ROTATION_COMPENSATION = 5011
    VSSC_ENABLE                  = 7000
    VSSC_DISABLE                 = 7001
    SHOW_DIALOG                  = 3000

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
    X     = 'X'
    Y     = 'Y'
    Z     = 'Z'
    FEED  = 'F'
    TOOL  = 'T'
    RPM   = 'S'
    ARC_X = 'I'
    ARC_Y = 'J'
    ARC_Z = 'K'
    ARC_R = 'R'

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
    help="Show gcode in FreeCAD Editor before saving to file.")

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

parser.add_argument('--home-before-start', action=argparse.BooleanOptionalAction, default=False,
    help="When enabled, machine will home in X, Y and Z directions prior to executing any operations.")

parser.add_argument('--allow-zero-rpm', action=argparse.BooleanOptionalAction, default=False,
    help="""
    When enabled, we will post-process jobs when the spindle is stationary.
    This may be useful when using a drag-knife or similar tool but should
    be left disabled for normal milling operations.
    """)

parser.add_argument('--version-check', action=argparse.BooleanOptionalAction, default=True,
    help="""
    When enabled, the post-processor will output a version check command
    to make sure the post-processor version and MillenniumOS version installed
    in RRF match.
    """)
probe_mode = parser.add_mutually_exclusive_group(required=False)
probe_mode.add_argument('--probe-at-start', dest='probe_mode', action='store_const', const=PROBE.AT_START, default=PROBE.ON_CHANGE,
    help="When enabled, MillenniumOS will probe a work-piece in each used WCS prior to executing any operations.")

probe_mode.add_argument('--probe-on-change', dest='probe_mode', action='store_const', const=PROBE.ON_CHANGE,
    help="When enabled, MillenniumOS will probe a work-piece just prior to switching into each used WCS.")

probe_mode.add_argument('--no-probe', dest='probe_mode', action='store_const', const=PROBE.NONE)

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
    def __init__(self, typ=None, fmt='{!s}', prefix=None, ctrl=Control.NONE, modals=None, vars = None):
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

        self.modals = []
        self.modalindex = {}
        self.activemodals = []

        if modals is not None:
            for g in modals:
                self.modals.append(set(g))
                for c in g:
                    i = len(self.modals)-1
                    self.modalindex[self.format(c, ctrl=Control.NONE)] = i
                    self.activemodals.insert(i, None)



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

        # Even with force, we want to check and make sure we
        # dont output modal codes if they are already active.
        if outCode in self.modalindex:
            i = self.modalindex[outCode]
            m = self.modals[i]

            if outCode == self.activemodals[i]:
                return (None, None)
            else:
                self.activemodals[i] = outCode

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
                    if argOut is not None and len(argOut) > 0:
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

        setattr(self, Section.RUN, [])
        setattr(self, Section.PRE, [])
        setattr(self, Section.POST, [])

        # Set default section
        self.oldSection = Section.RUN
        self.curSection = Section.RUN
        self.additions  = []
        # Set default action
        self.prepend    = False

        # Switch to PRE section
        with self.Section(Section.PRE):
            self.comment('Exported by FreeCAD')
            self.comment('Post Processor: {} by {}'.format(self.name, self.vendor))
            self.comment('Output Time: {}'.format(datetime.now(timezone.utc)))
            self.brk()

    @contextmanager
    def Section(self, section, prepend=False):
        self.oldSection = self.curSection
        self.curSection = section
        self.additions = []
        self.prepend = prepend
        try:
            yield
        finally:
            if not self.prepend:
                getattr(self, self.curSection).extend(self.additions)
            else:
                getattr(self, self.curSection)[:0] = self.additions

            self.curSection = self.oldSection
            self.oldSection = Section.RUN

            self.prepend = False

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
        self.brk()
        if hasattr(obj, 'Proxy'):
            proxy_type = type(obj.Proxy).__name__

            match proxy_type:
                case 'Comment':
                    # If an oncomment function is available, call it
                    if hasattr(self, 'oncomment') and callable(getattr(self, 'oncomment')):
                        self.oncomment(obj)
                case 'Fixture':
                    if hasattr(self, 'onfixture') and callable(getattr(self, 'onfixture')):
                        self.onfixture(obj)
                case 'ToolController':
                    self.ontoolcontroller(obj)
                case _:
                    self.onoperation(obj)

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

    # Output a comment to the active section
    def comment(self, msg):
        self.cmd('({})'.format(msg))

    # Output a command to the active section
    def cmd(self, cmd):
        if cmd is not None:
            self.additions.append(cmd)

    # Output a break to the active section
    def brk(self):
        self.additions.append('')

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
    _CANNED_CYCLES         = [73, 81, 83]
    _UNSUPPORTED           = [98, 99]

    # Define command output formatters
    _G   = Output(fmt=FORMATS.CMD, prefix='G', vars = [
            Output(prefix=ARGS.X, fmt=FORMATS.AXES),
            Output(prefix=ARGS.Y, fmt=FORMATS.AXES),
            Output(prefix=ARGS.Z, fmt=FORMATS.AXES),
            Output(prefix=ARGS.ARC_X, fmt=FORMATS.AXES, ctrl=Control.NONZERO),
            Output(prefix=ARGS.ARC_Y, fmt=FORMATS.AXES, ctrl=Control.NONZERO),
            Output(prefix=ARGS.ARC_Z, fmt=FORMATS.AXES, ctrl=Control.NONZERO),
            Output(prefix=ARGS.ARC_R, fmt=FORMATS.AXES, ctrl=Control.NONZERO),
            Output(prefix=ARGS.FEED, fmt=FORMATS.FEED, ctrl=Control.NONZERO),
            Output(prefix='R', typ=str, fmt=FORMATS.STR),
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
            Output(prefix='S', fmt=FORMATS.RPM, ctrl=Control.FORCE),
            Output(prefix='V', typ=str, fmt=FORMATS.STR, ctrl=Control.FORCE),
            # This acts as default output for V if it does not match the
            # type specified above.
            Output(prefix='V', fmt=FORMATS.RPM, ctrl=Control.FORCE),
        ], ctrl=Control.FORCE)

    _T   = Output(fmt=FORMATS.CMD, prefix='T', ctrl=Control.FORCE)

    def __init__(self, args={}):
        post_name = "MillenniumOS {}".format(RELEASE.VERSION)

        super().__init__(post_name, vendor=RELEASE.VENDOR, args=args)
        self._MOVES           = self._LINEAR_MOVES + self._ARC_MOVES + self._CANNED_CYCLES
        self._SPINDLE_ACTIONS = self._SPINDLE_ACTIONS_START + self._SPINDLE_ACTIONS_STOP
        self.active_wcs      = False
        self.used_wcs        = []
        self.tools           = {}
        self.xy_seen         = False
        self.delayed_z       = None
        self.spindle_started = False

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

    def _forceArcParams(self):
        self._G.reset([ARGS.ARC_X, ARGS.ARC_Y, ARGS.ARC_Z, ARGS.ARC_R])

    def _forceLinearParams(self):
        self._G.reset([ARGS.X, ARGS.Y, ARGS.Z])

    def _forceAll(self):
        self._forceFeed()
        self._forceTool()
        self._forceSpindle()
        self._forceArcParams()
        self._forceLinearParams()

    def T(self, code):
        cmd, _ = self._T(code)
        if not cmd:
            return None
        return self.cmd(' '.join(cmd))

    def G(self, code, **params):
        # Do not output unsupported codes
        if code in self._UNSUPPORTED:
            return None

        # Reset tools, feed and spindle on park
        if code == GCODES.PARK:
            self.onpark(code, params)

        # If WCS is changing
        elif code in self._WCS_CHANGES:
            self.onwcs(code, params)


        elif code in self._MOVES:
            self.onmove(code, params)
        else:
            # Parse and format the command into a list
            cmd, _ = self._G(code, **params)
            if not cmd:
                return None

            self.cmd(' '.join(cmd))

    def M(self, code, **params):

        # If code is a tool change, send the T command
        # and return so the M6 is not output.
        if ARGS.TOOL in params and code in self._TOOL_CHANGES:
            self.ontoolchange(code, params)

        elif code in self._SPINDLE_ACTIONS:
            self.onspindle(code, params)
        else:
            cmd, _ = self._M(code, **params)
            if not cmd:
                return None
            self.cmd(' '.join(cmd))

    def probe(self, wcsOffset=None):
        if wcsOffset is None:
            self.comment("Probe origin in current WCS")
            self.G(GCODES.PROBE_OPERATOR)
        else:
            self.comment("Probe origin and save in WCS {}".format(wcsOffset))
            self.G(GCODES.PROBE_OPERATOR, W=wcsOffset)
        self.brk()

    # Add tool index, name and params to tool info
    def addtool(self, index, name, params):
        if index in self.tools and name != self.tools[index]['name']:
            raise ValueError("Duplicate tool index {} with different descriptions!".format(index))

        if len(name) < 1:
            raise ValueError("Tool name must not be empty!")

        self.tools[index] = {"name": name, "params": params}

    # Return tool info
    def toolinfo(self):
        return self.tools

    # Note: these functions are called based on the object type - these
    # do not refer to indivudal gcode commands, but are triggered at the
    # start of each new object.
    def oncomment(self, obj):
        self.comment("Output confirmable dialog to operator")
        self.M(MCODES.SHOW_DIALOG, R="FreeCAD", S=obj.Comment)


    def onpark(self, _, __):
        self._forceTool()
        self._forceFeed()
        self._forceSpindle()
        self.spindle_started = False

    def onwcs(self, code, params):
        wcsOffset = int(code - (self._WCS_CHANGES[0]-1))
        self.used_wcs.append(wcsOffset)

        if self.active_wcs:
            self.comment("Park ready for WCS change")
            self.G(GCODES.PARK)
            self.brk()

        self.comment("Switch to WCS {}".format(wcsOffset))

        cmd, _ = self._G(code, **params)
        if not cmd:
            return None
        self.cmd(' '.join(cmd))

        self.active_wcs = True
        self.brk()

        # With the WCS active, we can now call probe and rotation
        # compensation commands without a WCS offset - they default
        # to the active WCS.

        # Only probe inline if probe_on_change is set
        if self.args.probe_mode == PROBE.ON_CHANGE:
            self.probe()
            self.spindle_started = False


        self.comment("Enable rotation compensation if necessary")
        self.M(MCODES.ENABLE_ROTATION_COMPENSATION)

        return None

    def onmove(self, code, params):

        # Make sure the first arc move after a linear move
        # contains the right parameters.
        if code in self._LINEAR_MOVES:
            self._forceArcParams()

        # Make sure the first linear move after an arc move
        # contains the right parameters.
        if code in self._ARC_MOVES:
            self._forceLinearParams()

        cmd, changed = self._G(code, **params)
        if not cmd or not changed:
            return

        # If feed rate was changed
        if ARGS.FEED in changed:
            # But the code only has a feed arg
            # Then do not output the command at all and
            # make sure it is outputted with the next command
            if len(changed) == 1:
                self._forceFeed()
                return

            # And command is a rapid move
            if code in self._RAPID_MOVES:
                # Then ignore the feed arg
                # as rapid moves follow machine limits
                del cmd[changed[ARGS.FEED]]
                # Make sure feed is output by the next
                # non-rapid move.
                self._forceFeed()

        # If we haven't seen an X/Y move since starting the operation
        if not self.xy_seen:
            # And Z has been changed
            if ARGS.Z in changed:
                # Then store the Z height for later
                self.delayed_z = [cmd, changed]
                return

            if ARGS.X in changed or ARGS.Y in changed:
                self.xy_seen = True

        # Otherwise if we have seen an X/Y move and there is a delayed Z,
        # then output the delayed move.
        elif self.delayed_z is not None:
            dcmd, _ = self.delayed_z
            self.brk()
            self.comment("Delayed Z move following XY")
            self.cmd(' '.join(dcmd))
            self.delayed_z = None
            self.brk()

        self.cmd(' '.join(cmd))

    def ontoolchange(self, _, params):
        self.T(params[ARGS.TOOL])
        self.spindle_started = False
        self.brk()
        return False

    def onspindle(self, code, params):
        if ARGS.RPM in params and code in self._SPINDLE_ACTIONS_START:
            self.comment("Start spindle at requested RPM and wait for it to accelerate")
            self.spindle_started = True
        if code in self._SPINDLE_ACTIONS_STOP:
            self.comment("Stop spindle and wait for it to decelerate")
            self.spindle_started = False

        code += self._SPINDLE_WAIT_SUFFIX

        cmd, _ = self._M(code, **params)
        if not cmd:
            return None

        self.cmd(' '.join(cmd))


    def onfixture(self, _):
        self._forceTool()
        self._forceFeed()
        self._forceSpindle()
        self.spindle_started = False


    def onoperation(self, op):
        self.comment('Begin Operation: {}'.format(op.Label))

        # Make sure spindle is started unless we allow zero RPM
        if not self.spindle_started and not self.args.allow_zero_rpm:
            raise ValueError("Spindle not started before operation {}".format(op.Label))

        # Some FreeCAD operations will output a Z
        # move to the clearance height at the start of the operation
        # rather than moving to XY first and then down to the clearance
        # height. MillenniumOS enforces a parking location after
        # tool-changes so it is safe for us to move in the XY plane
        # first and then down to the clearance height, and this stops
        # us from scaring the operator by moving the tool downwards over
        # the toolsetter rather than over the workpiece first.

        # FreeCAD operations always return to clearance height after
        # completion so between operations we can move in XY before Z
        # as well.

        self.xy_seen = False

        self._forceAll()


    def ontoolcontroller(self, tc):
        self.comment('TC: {}'.format(tc.Tool.Label))
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

        tl = float(tc.Tool.Length.getValueAs(UNITS.LENGTH))
        fl = float(tc.Tool.CuttingEdgeHeight.getValueAs(UNITS.LENGTH)) if hasattr(tc.Tool, 'CuttingEdgeHeight') else tl

        tool_params = {
            "flutes": tc.Tool.Flutes,
            "radius": radius,
            "tool_length": tl,
            "flute_length": fl,
            "corner_radius": cr
        }
        self.addtool(tc.ToolNumber, tc.Label.strip("TC: "), tool_params)

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
            params[pkey] = self._parseparam(code, pkey, pvalue)

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
            # Convert FreeCAD feed-rate to machine feed rate and store
            # as an integer. Point something RPM is not necessary,
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
        return self.G(GCODES.RAPID, X=x, Y=y, Z=z, ctrl=Control.FORCE)

    def linear(self, x, y, z, f):
        return self.G(GCODES.LINEAR, X=x, Y=y, Z=z, F=f, ctrl=Control.FORCE)

    def output(self):
        with self.Section(Section.PRE):
            self.comment("Begin preamble")

            self.brk()
            self.comment("Check MillenniumOS version matches post-processor version")
            self.M(MCODES.VERSION_CHECK, V=RELEASE.VERSION, ctrl=Control.FORCE)

            # Parsing must be completed to enumerate all tools.
            tools = self.toolinfo()

            # Output tool details if enabled and tools are configured
            if self.args.output_tools and tools:
                self.brk()
                self.comment("Pass tool details to firmware")
                # Output tool info
                for index, tool in tools.items():
                    self.M(MCODES.ADD_TOOL, P=index, R=tool['params']['radius'], S=rrf_safe_string(tool['name'][:32]), ctrl=Control.FORCE)
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
            self.G(GCODES.ABSOLUTE) # Absolute moves
            self.G(GCODES.MILLIMETERS) # All units are millimeters
            self.G(GCODES.FEED_PER_MIN) # Feeds are per-minute
            self.brk()

            if self.args.vssc:
                self.comment("Enable Variable Spindle Speed Control")
                self.M(MCODES.VSSC_ENABLE, P=self.args.vssc_period, V=self.args.vssc_variance)

        # Switch to post to output ending commands
        with self.Section(Section.POST):
            self.brk()
            self.comment("Begin postamble")
            self.brk()
            self.comment("Park")
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
def export(objectslist, _, argstring):
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

    return out