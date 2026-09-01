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
import re

from Path.Post.Processor import PostProcessor
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
                prop["default"] = "G90\nG21\nG94"
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

        # The legacy post iterated Path.Command.Parameters directly, which
        # FreeCAD stores alphabetically. Verified against legacy output:
        #   G3 F1096 I-8.839 J8.839 X141.5 Y-51 Z-0.6
        #   G83 F99 Q4.05 R3 Z-43.468
        # The base class default is X,Y,Z,A,B,C,F,I,J,K,R,Q,P,S,T which would
        # reorder every motion line. Match the legacy ordering instead.
        values["PARAMETER_ORDER"] = [
            "A", "B", "C", "F", "H", "I", "J", "K", "L",
            "P", "Q", "R", "S", "T", "X", "Y", "Z",
        ]

    # ------------------------------------------------------------------
    # Number formatting
    # ------------------------------------------------------------------

    def format_parameter(self, param_name, value, command_name=None):
        """Strip trailing zeros and normalise negative zero.

        The base class emits fixed-precision values (X141.500, F1096.0). The
        legacy post stripped trailing zeros and the decimal point, and mapped
        "-0" to "0", giving X141.5 / F1096 / X0. Reproduce that so output is
        diffable against the legacy post and stays readable on the DWC console.
        """
        formatted = super().format_parameter(param_name, value, command_name)

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
        self._used_wcs = self._collect_used_wcs(postables)

        lines: List[str] = []

        lines.append("(WARNING: generated for a specific RRF/MillenniumOS configuration.)")
        lines.append("(That firmware implements safety checks and spindle controls this)")
        lines.append("(G-code assumes exist. DO NOT run on a machine without them.)")

        if self.values.get("VERSION_CHECK"):
            version = rrf_safe_string(str(self.values.get("MOS_VERSION", RELEASE.VERSION)))
            lines.append("(Check MillenniumOS version matches post-processor version)")
            lines.append(f'{MCODES.VERSION_CHECK} V"{version}"')

        if self.values.get("OUTPUT_TOOLS"):
            tools = self._collect_tools(postables)
            if tools:
                lines.append("(Pass tool details to firmware)")
                for number, tool in sorted(tools.items()):
                    name = rrf_safe_string(tool["name"][:32])
                    lines.append(
                        f'{MCODES.ADD_TOOL} P{int(number)} R{tool["radius"]:.3f} S"{name}"'
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

    def _convert_tool_change(self, command: Path.Command) -> str:
        """Emit a bare T word; MillenniumOS services the change in firmware.

        The legacy post suppressed M6 entirely and emitted T<n> on its own line.
        """
        tool = command.Parameters.get("T")
        if tool is None:
            return super()._convert_tool_change(command)

        # Reset modal state so the following M3 S... is not deduplicated away.
        self.machine_state.setState(None)
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
        self.machine_state.setState(None)

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
