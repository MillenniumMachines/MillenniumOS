# -*- coding: utf-8 -*-
# MillenniumOS Postprocessor for FreeCAD -- machine-based post flow.
#
# Copyright (C)2022-2024 Millennium Machines
#
# This is a port of millennium_os_post.py (now millennium_os_legacy_post.py)
# onto the FreeCAD CAM machine-post API introduced in the 1.2/26.x CAM rework.
#
# Design assumptions carried over unchanged from the legacy post:
#
# - Complex functionality (tool changes, WCS probing, tool length setting) is
#   handled in firmware. This post emits a single macro call and lets RRF
#   decide how to service it.
# - Your G27 (Park) macro raises Z away from the work piece _before_ M5.
# - Macros and firmware are responsible for safety checks.
#
# What the base PostProcessor class now handles, so it is NOT reimplemented here:
#   header construction, line numbering, comment formatting, coordinate/feed
#   precision, modal deduplication, canned-cycle expansion, XY-before-Z
#   decomposition, spindle spin-up dwell, coolant dwell, rapid translation.
# Those are driven by the `output` and `processing` sections of the .fcm file.

from typing import Any, Dict, List
import inspect
import re

from Path.Post.Processor import PostProcessor
import Constants
import Path
import FreeCAD

translate = FreeCAD.Qt.translate

Values = Dict[str, Any]

# Marks this module as a machine-flow post so Path.Preferences.classifyPostProcessor()
# reports "machine" and the Machine editor offers it in the postprocessor dropdown.
POST_TYPE = "machine"


class RELEASE:
    VERSION = "%%MOS_VERSION%%"
    VENDOR = "Millennium Machines"


class PROBE:
    AT_START = "AT_START"
    ON_CHANGE = "ON_CHANGE"
    NONE = "NONE"


class GCODES:
    PARK = "G27"
    HOME = "G28"
    PROBE_OPERATOR = "G6600"
    PROBE_REFERENCE_SURFACE = "G6511"


class MCODES:
    ADD_TOOL = "M4000"
    VERSION_CHECK = "M4005"
    ENABLE_ROTATION_COMPENSATION = "M5011"
    VSSC_ENABLE = "M7000"
    VSSC_DISABLE = "M7001"
    SHOW_DIALOG = "M3000"


# WCS G-code -> offset number, used to build probe calls.
WCS_OFFSETS = {
    "G54": 1,
    "G55": 2,
    "G56": 3,
    "G57": 4,
    "G58": 5,
    "G59": 6,
    "G59.1": 7,
    "G59.2": 8,
    "G59.3": 9,
}

# Spindle codes get a .9 suffix so RRF waits for the spindle to reach speed.
# Coolant M-codes are inserted into the operation Path by Path/Op/Base.py in
# FreeCAD 26.3, so the post never generates them -- it only labels them.
COOLANT_LABELS = {
    "M7": "Coolant on: Mist",
    "M07": "Coolant on: Mist",
    "M8": "Coolant on: Flood",
    "M08": "Coolant on: Flood",
    "M9": "Coolant off",
    "M09": "Coolant off",
}

SPINDLE_START = ("M3", "M03", "M4", "M04")
SPINDLE_STOP = ("M5", "M05")
SPINDLE_WAIT_SUFFIX = ".9"

# Canned-cycle mode commands MillenniumOS does not implement. The legacy post
# drops G98/G99 via _UNSUPPORTED, and G80 never appears in its output because
# RepRapFirmware has no modal canned-cycle state to cancel -- G83 is one-shot.
UNSUPPORTED_MODAL = ("G80", "G98", "G99")

# Commands treated as motion when reordering the approach at operation start.
MOVE_COMMANDS = (
    "G0", "G00", "G1", "G01", "G2", "G02", "G3", "G03",
    "G73", "G81", "G82", "G83",
)

# MillenniumOS custom codes must appear in supported_commands or
# convert_command_to_gcode() raises CAMValueError.
MOS_EXTRA_COMMANDS = [
    "G27",
    "G6511",
    "G6600",
    "M3.9",
    "M4.9",
    "M5.9",
    "M3000",
    "M4000",
    "M4005",
    "M5011",
    "M7000",
    "M7001",
]


def rrf_safe_string(s):
    """RRF strings disallow some characters; quotes must be doubled."""
    return re.sub(r'([^"0-9a-z\.:,=_\-\s])', "", s, flags=re.IGNORECASE).replace('"', '""')


class MillenniumOSMachine(PostProcessor):
    """MillenniumOS post processor using the machine-based flow."""

    # ------------------------------------------------------------------
    # Property schema
    # ------------------------------------------------------------------

    @classmethod
    def get_common_property_schema(cls):
        """Override base defaults with MillenniumOS values."""
        common_props = super().get_common_property_schema()

        for prop in common_props:
            name = prop["name"]
            if name == "file_extension":
                prop["default"] = "gcode"
            elif name == "supports_tool_radius_compensation":
                # MOS does not use G41/G42; compensation happens in CAM.
                prop["default"] = False
            elif name == "supported_commands":
                existing = prop["default"].split("\n")
                prop["default"] = "\n".join(existing + MOS_EXTRA_COMMANDS)
            elif name == "drill_cycles_to_translate":
                # MillenniumOS/RRF implements G73/G81/G83 natively -- verified in
                # legacy output, which emits "G83 F99 Q4.05 R3 Z-43.468" unexpanded.
                # Leave empty so the base class passes canned cycles through.
                prop["default"] = ""
            elif name == "preamble":
                # Movement configuration only. Everything else that the legacy
                # post emitted up front is built in _expand_prefix() because it
                # depends on the job (tool table, used WCSs).
                # G21 is emitted separately by _collect_unit_command() from
                # output.units, so including it here would duplicate it.
                prop["default"] = "G90\nG94"
            elif name == "postamble":
                # Park first: G27 lifts Z clear before stopping the spindle.
                prop["default"] = "M9\nG27"
            elif name == "safetyblock":
                prop["default"] = ""

        return common_props

    @classmethod
    def get_property_schema(cls):
        """MillenniumOS-specific properties, editable in the Machine editor."""
        return [
            {
                "name": "mos_version",
                "type": "string",
                "label": translate("CAM", "MillenniumOS Version"),
                "default": RELEASE.VERSION,
                "help": translate(
                    "CAM",
                    "MillenniumOS version this post targets. Emitted in the M4005 "
                    "version check so firmware can refuse mismatched G-code.",
                ),
            },
            {
                "name": "version_check",
                "type": "bool",
                "label": translate("CAM", "Version Check"),
                "default": True,
                "help": translate(
                    "CAM",
                    "Emit M4005 to verify the MillenniumOS version installed in RRF "
                    "matches the version this post targets.",
                ),
            },
            {
                "name": "output_tools",
                "type": "bool",
                "label": translate("CAM", "Output Tool Details"),
                "default": True,
                "help": translate(
                    "CAM",
                    "Emit M4000 tool definitions in the preamble. Disabling this makes "
                    "tool changes considerably harder for the operator.",
                ),
            },
            {
                "name": "output_job_setup",
                "type": "bool",
                "label": translate("CAM", "Output Job Setup"),
                "default": True,
                "help": translate(
                    "CAM",
                    "Emit supplemental setup commands (homing, reference surface probe, "
                    "WCS probing). Disable to drive setup manually.",
                ),
            },
            {
                "name": "home_before_start",
                "type": "bool",
                "label": translate("CAM", "Home Before Start"),
                "default": False,
                "help": translate("CAM", "Emit G28 to home all axes before any operations."),
            },
            {
                "name": "probe_mode",
                "type": "choice",
                "runtime": True,
                "label": translate("CAM", "WCS Probing Mode"),
                "default": PROBE.ON_CHANGE,
                "choices": [PROBE.AT_START, PROBE.ON_CHANGE, PROBE.NONE],
                "help": translate(
                    "CAM",
                    "AT_START probes every used WCS up front; ON_CHANGE probes each WCS "
                    "just before switching into it; NONE skips probing entirely.",
                ),
            },
            {
                "name": "allow_zero_rpm",
                "type": "bool",
                "label": translate("CAM", "Allow Zero RPM"),
                "default": False,
                "help": translate(
                    "CAM",
                    "Permit posting operations with a stationary spindle. Useful for "
                    "drag knives; leave disabled for milling.",
                ),
            },
            {
                "name": "vssc",
                "type": "bool",
                "runtime": True,
                "label": translate("CAM", "Variable Spindle Speed Control"),
                "default": True,
                "help": translate(
                    "CAM",
                    "Vary spindle speed around the requested RPM to avoid harmonic "
                    "resonance between tool and work piece.",
                ),
            },
            {
                "name": "vssc_period",
                "type": "int",
                "runtime": True,
                "label": translate("CAM", "VSSC Period (ms)"),
                "default": 4000,
                "min": 100,
                "max": 60000,
                "help": translate("CAM", "Period over which RPM is varied, in milliseconds."),
            },
            {
                "name": "vssc_variance",
                "type": "int",
                "runtime": True,
                "label": translate("CAM", "VSSC Variance (RPM)"),
                "default": 200,
                "min": 0,
                "max": 5000,
                "help": translate("CAM", "Variance around target RPM when VSSC is enabled."),
            },
        ]

    # ------------------------------------------------------------------
    # Construction
    # ------------------------------------------------------------------

    def __init__(
        self,
        job,
        tooltip=translate("CAM", "MillenniumOS post processor (machine flow)"),
        tooltipargs=[],
        units="Metric",
    ) -> None:
        super().__init__(job=job, tooltip=tooltip, tooltipargs=tooltipargs, units=units)
        self._used_wcs: List[int] = []
        self._active_wcs = False
        Path.Log.debug("MillenniumOS machine post processor initialized.")

    def init_values(self, values: Values) -> None:
        super().init_values(values)
        values["POSTPROCESSOR_FILE_NAME"] = __name__


    # ------------------------------------------------------------------
    # Number formatting
    # ------------------------------------------------------------------

    #: Cached arity check for the base format_parameter(). The command_name
    #: argument was added partway through the 26.x CAM rework, so builds differ.
    _parent_takes_command_name = None

    @classmethod
    def _parent_format_accepts_command_name(cls):
        if cls._parent_takes_command_name is None:
            try:
                params = inspect.signature(
                    super(MillenniumOSMachine, cls).format_parameter
                ).parameters
                cls._parent_takes_command_name = "command_name" in params or any(
                    p.kind in (p.VAR_POSITIONAL, p.VAR_KEYWORD) for p in params.values()
                )
            except (TypeError, ValueError):
                cls._parent_takes_command_name = False
        return cls._parent_takes_command_name

    def format_parameter(self, param_name, value, command_name=None):
        """Strip trailing zeros and normalise negative zero.

        The base class emits fixed-precision values (X141.500, F1096.0). The
        legacy post stripped trailing zeros and the decimal point, and mapped
        "-0" to "0", giving X141.5 / F1096 / X0. Reproduce that so output is
        diffable against the legacy post and stays readable on the DWC console.
        """
        if self._parent_format_accepts_command_name():
            formatted = super().format_parameter(param_name, value, command_name)
        else:
            formatted = super().format_parameter(param_name, value)

        if not isinstance(formatted, str):
            return formatted

        if "." in formatted:
            formatted = formatted.rstrip("0").rstrip(".")

        if formatted == "-0":
            formatted = "0"

        return formatted

    # ------------------------------------------------------------------
    # Preamble construction
    # ------------------------------------------------------------------

    def _collect_tools(self, postables):
        """Walk the postable list and gather tool definitions for M4000.

        Returns an ordered dict of tool_number -> {name, radius}.
        """
        tools: Dict[int, Dict[str, Any]] = {}

        for _section_name, sublist in postables:
            for item in sublist:
                if item.item_type != "tool_controller":
                    continue

                number = item.data.get("tool_number")
                if number is None:
                    continue

                tc = item.source
                tool = getattr(tc, "Tool", None)
                if tool is None:
                    continue

                radius = float(tool.Diameter.getValueAs("mm")) / 2.0
                name = item.label.replace("TC: ", "").strip()

                if number in tools and tools[number]["name"] != name:
                    raise ValueError(
                        f"Duplicate tool index {number} with different descriptions"
                    )

                tools[number] = {"name": name, "radius": radius}

        return tools

    def _collect_used_wcs(self, postables):
        """Collect the WCS offsets referenced by fixture items, in first-use order."""
        used: List[int] = []

        for _section_name, sublist in postables:
            for item in sublist:
                if item.item_type != "fixture" or not item.path:
                    continue
                for cmd in item.path.Commands:
                    offset = WCS_OFFSETS.get(cmd.Name)
                    if offset is not None and offset not in used:
                        used.append(offset)

        return used

    def _expand_prefix(self, postables):
        """Prepend MillenniumOS job setup ahead of the standard preamble.

        The base class emits SAFETYBLOCK, header, PREAMBLE, units and PRE_JOB.
        We build the job-dependent MOS block (version check, tool table, setup
        probing, VSSC) and prepend it to PREAMBLE so ordering is preserved.
        """
        # The legacy post iterated Path.Command.Parameters directly, which
        # FreeCAD stores alphabetically. Verified against legacy output:
        #   G3 F1096 I-8.839 J8.839 X141.5 Y-51 Z-0.6
        #   G83 F99 Q4.05 R3 Z-43.468
        # The base default is X,Y,Z,A,B,C,F,I,J,K,R,Q,P,S,T, which reorders
        # every motion line. Set here rather than in init_values() because
        # apply_configuration_bundle() resets self.values wholesale in Stage 0.
        self.values["PARAMETER_ORDER"] = [
            "A", "B", "C", "F", "H", "I", "J", "K", "L",
            "P", "Q", "R", "S", "T", "X", "Y", "Z",
        ]

        self._used_wcs = self._collect_used_wcs(postables)

        lines: List[str] = []

        lines.append("(WARNING: generated for a specific RRF/MillenniumOS configuration.)")
        lines.append("(That firmware implements safety checks and spindle controls this)")
        lines.append("(G-code assumes exist. DO NOT run on a machine without them.)")

        if self.values.get("VERSION_CHECK"):
            version = str(self.values.get("MOS_VERSION", RELEASE.VERSION))
            if "%%" in version:
                raise ValueError(
                    "mos_version is still the build placeholder "
                    f"({version!r}). Set it in the machine definition to the "
                    "MillenniumOS version installed in firmware."
                )
            version = rrf_safe_string(version)
            lines.append("(Check MillenniumOS version matches post-processor version)")
            lines.append(f'{MCODES.VERSION_CHECK} V"{version}"')

        if self.values.get("OUTPUT_TOOLS"):
            tools = self._collect_tools(postables)
            if tools:
                lines.append("(Pass tool details to firmware)")
                for number, tool in tools.items():
                    name = rrf_safe_string(tool["name"][:32])
                    radius = f'{tool["radius"]:.3f}'.rstrip("0").rstrip(".")
                    lines.append(
                        f'{MCODES.ADD_TOOL} P{int(number)} R{radius} S"{name}"'
                    )

        if self.values.get("OUTPUT_JOB_SETUP"):
            if self.values.get("HOME_BEFORE_START"):
                lines.append("(Home before start)")
                lines.append(GCODES.HOME)

            lines.append("(Probe reference surface if necessary)")
            lines.append(GCODES.PROBE_REFERENCE_SURFACE)

            probe_mode = self.values.get("PROBE_MODE", PROBE.ON_CHANGE)
            lines.append(f"(WCS Probing Mode: {probe_mode})")

            if probe_mode == PROBE.AT_START:
                for wcs in self._used_wcs:
                    lines.append(f"(Probe origin and save in WCS {wcs})")
                    lines.append(f"{GCODES.PROBE_OPERATOR} W{wcs}")

        if self.values.get("VSSC"):
            period = int(self.values.get("VSSC_PERIOD", 4000))
            variance = int(self.values.get("VSSC_VARIANCE", 200))
            lines.append("(Enable Variable Spindle Speed Control)")
            lines.append(f"{MCODES.VSSC_ENABLE} P{period} V{variance}")

        mos_block = "\n".join(lines)

        existing = self.values.get("PREAMBLE") or ""
        self.values["PREAMBLE"] = f"{mos_block}\n{existing}" if existing else mos_block

        # Trailing block, appended after the configured postamble so the order
        # matches the legacy post: coolant off, park, VSSC off, coolant off, spindle off.
        tail: List[str] = []
        if self.values.get("VSSC"):
            tail.append("(Disable Variable Spindle Speed Control)")
            tail.append(MCODES.VSSC_DISABLE)
        tail.append("(Double-check coolant is off!)")
        tail.append("M9")
        tail.append("(Double-check spindle is stopped!)")
        tail.append(f"M5{SPINDLE_WAIT_SUFFIX}")

        existing_post = self.values.get("POSTAMBLE") or ""
        tail_block = "\n".join(tail)
        self.values["POSTAMBLE"] = (
            f"{existing_post}\n{tail_block}" if existing_post else tail_block
        )

        super()._expand_prefix(postables)

    # ------------------------------------------------------------------
    # Command conversion hooks
    # ------------------------------------------------------------------

    #: Sentinel emitted at operation / tool-change / fixture boundaries and
    #: consumed by _optimize_gcode(). Never reaches the output file.
    MODAL_BARRIER_MARKER = "(MOS-MODAL-BARRIER)"

    @staticmethod
    def _delay_leading_z(commands):
        """Defer a leading Z-only move until after the first XY move.

        FreeCAD emits the approach as "G0 Z5" then "G0 X.. Y..". After a tool
        change MillenniumOS has parked, so the machine sits high and over the
        toolsetter. Descending to clearance *before* traversing means the
        descent happens at the park position and the traverse then happens at
        clearance height -- straight through whatever is between, the toolsetter
        included.

        Reordering to XY first keeps the traverse at the (high, safe) park
        height and descends only once above the target. This is the legacy
        post's delayed_z / xy_seen behaviour, reset per operation.

        Only pure-Z moves are deferred; anything carrying X or Y is left alone.
        The legacy version deferred any move whose Z changed, which would also
        swallow a combined XYZ move. Any move still held at the end of the item
        is flushed rather than dropped.
        """
        result = []
        held = []
        xy_seen = False

        for command in commands:
            if command.Name not in MOVE_COMMANDS:
                result.append(command)
                continue

            params = command.Parameters
            has_xy = "X" in params or "Y" in params
            has_z = "Z" in params

            if not xy_seen:
                if has_xy:
                    xy_seen = True
                    result.append(command)
                elif has_z:
                    held.append(command)
                else:
                    result.append(command)
                continue

            # Flush before the next move, not immediately after the XY, so any
            # coolant-on between them still precedes the descent.
            if held:
                result.extend(held)
                held = []
            result.append(command)

        result.extend(held)
        return result

    def _convert_item_commands(self, item, gcode_lines) -> None:
        """Reorder the approach, and mark boundaries for _optimize_gcode()."""
        item_type = getattr(item, "item_type", None)

        if item_type in ("operation", "tool_controller", "fixture"):
            gcode_lines.append(self.MODAL_BARRIER_MARKER)

        if item_type == "operation" and item.path and item.path.Commands:
            reordered = self._delay_leading_z(list(item.path.Commands))
            if reordered != list(item.path.Commands):
                item.path = Path.Path(reordered)

        return super()._convert_item_commands(item, gcode_lines)

    def _optimize_gcode(self, gcode_lines):
        """Suppress redundant axis words per operation rather than across the whole job.

        GcodeProcessingUtils.suppress_redundant_axes_words() tracks position
        across the entire body and resets only on an M6 line. This post
        suppresses M6 (MillenniumOS services tool changes in firmware from a
        bare T word), so the reset never fires. Position is then tracked across
        a park and tool change, and a retract such as "G0 Z5" at the start of an
        operation is dropped as redundant, leaving a bare "G0" -- no retract
        before the following XY rapid. The legacy post avoids this by calling
        _forceAll() in onoperation(), ontoolchange() and onfixture().

        Here the body is split at the boundary markers emitted by
        _convert_item_commands(), each segment is suppressed independently, and
        the base is then called with suppression disabled so it is not redone
        across the whole body.
        """
        marker = self.MODAL_BARRIER_MARKER

        def strip_markers(lines):
            return [ln for ln in lines if ln.strip() != marker]

        if not gcode_lines:
            return super()._optimize_gcode(gcode_lines)

        # Suppression already off: markers just need removing.
        if self.values.get("OUTPUT_DOUBLES"):
            return super()._optimize_gcode(strip_markers(gcode_lines))

        from Path.Post.GcodeProcessingUtils import suppress_redundant_axes_words

        split_at = self._optimize_start or 0
        header = strip_markers(gcode_lines[:split_at])
        body = gcode_lines[split_at:]

        suppressed = []
        segment = []
        for line in body:
            if line.strip() == marker:
                suppressed.extend(suppress_redundant_axes_words(segment))
                segment = []
            else:
                segment.append(line)
        suppressed.extend(suppress_redundant_axes_words(segment))

        # Base would otherwise run the same suppression across the whole body.
        saved = self.values["OUTPUT_DOUBLES"]
        self.values["OUTPUT_DOUBLES"] = True
        try:
            return super()._optimize_gcode(header + suppressed)
        finally:
            self.values["OUTPUT_DOUBLES"] = saved

    def _reset_modal_state(self):
        """Force every tracked modal to re-emit on the next command.

        _convert_move() suppresses a parameter when machine_state.previous[p]
        equals it, and addCommand() repopulates `previous` from the live state
        before each conversion. So the only way to defeat the suppression is to
        null the live state; setting `previous` directly is overwritten.

        Nulls the attributes directly rather than calling setState(None) so
        this does not depend on that method existing. Logs loudly if it cannot
        reset -- a silent no-op here looks exactly like the feature working.
        """
        state = getattr(self, "machine_state", None)
        if state is None:
            Path.Log.error(
                "MillenniumOS: machine_state unavailable, cannot reset modals. "
                "Retracts may be suppressed as duplicates."
            )
            return

        tracked = getattr(state, "Tracked", None)
        if not tracked:
            Path.Log.error(
                "MillenniumOS: machine_state has no Tracked list, cannot reset modals."
            )
            return

        for key in tracked:
            try:
                setattr(state, key, None)
            except Exception as exc:  # noqa: BLE001 - diagnostic only
                Path.Log.error(f"MillenniumOS: could not null modal {key}: {exc}")

    def _convert_tool_change(self, command: Path.Command) -> str:
        """Emit a bare T word; MillenniumOS services the change in firmware.

        The legacy post suppressed M6 entirely and emitted T<n> on its own line.
        """
        tool = command.Parameters.get("T")
        if tool is None:
            return super()._convert_tool_change(command)

        # Reset modal state so the following M3 S... is not deduplicated away.
        self._reset_modal_state()
        return f"T{int(tool)}"

    def _convert_spindle_command(self, command: Path.Command) -> str:
        """Append the .9 wait suffix so RRF blocks until the spindle is at speed."""
        name = command.Name

        if name in SPINDLE_START:
            base = name.replace("M0", "M").rstrip()
            rpm = command.Parameters.get("S")
            suffixed = f"{base}{SPINDLE_WAIT_SUFFIX}"
            if rpm is not None:
                return f"{suffixed} S{int(rpm)}"
            return suffixed

        if name in SPINDLE_STOP:
            return f"M5{SPINDLE_WAIT_SUFFIX}"

        return super()._convert_spindle_command(command)

    def _convert_rapid_move(self, command: Path.Command) -> str:
        """Drop F from G0. Rapids run at machine limits under MillenniumOS.

        The base class checks F_FOR_RAPID_MOVES inside the `elif` of the
        duplicate-parameter test, so with output.duplicates.parameters = false
        that branch never runs and "G0 Z5 F0" leaks through.
        """
        if "F" in command.Parameters:
            trimmed = {k: v for k, v in command.Parameters.items() if k != "F"}
            command = Path.Command(command.Name, trimmed)

        gcode = super()._convert_rapid_move(command)

        # Drop a rapid whose axis words were all removed as unchanged. The base
        # class has this guard for GCODE_MOVE_LINE/ARC/DWELL but not for rapids,
        # so a bare "G0" no-op leaks through.
        if isinstance(gcode, str) and len(gcode.split()) == 1:
            return None

        return gcode

    def _convert_arc_move(self, command: Path.Command) -> str:
        """Drop zero-valued I/J/K from arcs.

        The legacy post marked the arc offsets Control.NONZERO, so a zero
        offset was omitted entirely -- "G3 J-12.5 X-12.5 Y0" with no I. The
        base class emits every parameter present, producing a spurious K0 on
        every G17-plane arc.
        """
        zeros = [k for k in ("I", "J", "K") if command.Parameters.get(k) == 0]
        if zeros:
            kept = {k: v for k, v in command.Parameters.items() if k not in zeros}
            command = Path.Command(command.Name, kept)

        return super()._convert_arc_move(command)

    def _convert_modal_command(self, command: Path.Command) -> str:
        """Drop canned-cycle mode commands MillenniumOS does not implement.

        FreeCAD brackets each drill cycle with G98 (return to initial Z) and
        G80 (cancel cycle). RRF treats G83 as one-shot with an explicit R, so
        there is no modal state to set or cancel, and MillenniumOS lists G98
        and G99 as unsupported outright. Legacy output contains none of the
        three; without this the machine post emitted 84 of each on a
        drilling-heavy job.
        """
        if command.Name in UNSUPPORTED_MODAL:
            return None

        return super()._convert_modal_command(command)

    def _convert_coolant_command(self, command: Path.Command) -> str:
        """Prefix coolant M-codes with the legacy post's descriptive comment.

        FreeCAD 26.3 inserts bare M7/M8/M9 into the operation Path itself
        (Path/Op/Base.py, around the first and last GCODE_MOVE), so there is
        nothing to emit here -- only to label, matching legacy output:

            (Coolant on: Mist)
            M7
        """
        label = COOLANT_LABELS.get(command.Name)
        gcode = super()._convert_coolant_command(command)

        if label is None or not gcode:
            return gcode

        return f"({label})\n{gcode}"

    def _convert_fixture(self, command: Path.Command) -> str:
        """Park before a WCS change, then optionally probe and enable rotation comp."""
        offset = WCS_OFFSETS.get(command.Name)
        if offset is None:
            return super()._convert_fixture(command)

        lines: List[str] = []

        if self._active_wcs:
            lines.append("(Park ready for WCS change)")
            lines.append(GCODES.PARK)

        lines.append(f"(Switch to WCS {offset})")
        lines.append(command.Name)

        self._active_wcs = True

        if self.values.get("PROBE_MODE") == PROBE.ON_CHANGE:
            lines.append("(Probe origin in current WCS)")
            lines.append(GCODES.PROBE_OPERATOR)

        lines.append("(Enable rotation compensation if necessary)")
        lines.append(MCODES.ENABLE_ROTATION_COMPENSATION)

        # Modal state is meaningless across a park/probe cycle.
        self._reset_modal_state()

        return "\n".join(lines)

    # ------------------------------------------------------------------
    # Sanity checks
    # ------------------------------------------------------------------

    def get_sanity_checks(self, job):
        """Warn about configurations MillenniumOS cannot service safely."""
        issues = super().get_sanity_checks(job)

        machine = self._machine
        if machine is None:
            return issues

        if len(machine.rotary_axes) > 0:
            issues.append(
                translate(
                    "CAM",
                    "MillenniumOS supports 3 axes only; rotary axes in the machine "
                    "definition will be ignored.",
                )
            )

        if len(machine.toolheads) > 1:
            issues.append(
                translate("CAM", "MillenniumOS supports a single spindle only.")
            )

        if not self.values.get("VERSION_CHECK"):
            issues.append(
                translate(
                    "CAM",
                    "Version checking is disabled. G-code may not match the "
                    "MillenniumOS version installed in firmware.",
                )
            )

        return issues

    @property
    def tooltip(self):
        return """
        MillenniumOS post processor (machine flow).

        Targets RepRapFirmware running MillenniumOS. Tool changes, WCS probing
        and tool length setting are delegated to firmware macros. Requires a
        machine definition; output options are configured there rather than
        through command-line arguments.
        """

    @property
    def units(self):
        return self._units


# PostProcessorFactory.get_post_processor() resolves the class as
# postname.title(), where postname is the filename minus "_post.py".
# So "millennium_os_machine" -> "Millennium_Os_Machine". The name must match
# exactly or the factory raises AttributeError, silently falls back to
# WrapperPost, and fails with "The script does not have an 'export' function".
Millennium_Os_Machine = MillenniumOSMachine
