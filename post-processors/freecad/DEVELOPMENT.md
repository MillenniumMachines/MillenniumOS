# FreeCAD Machine Post: Developer Notes

This document records implementation details and upstream behavior that are not needed for normal installation or machine setup. The user guide is in [README.md](README.md).

## Base-class responsibilities

The FreeCAD `PostProcessor` base class handles these features through the machine definition:

| Legacy behavior | Machine definition |
|---|---|
| argparse options | property schema and Machine editor |
| header and comments | `output.header.*`, `output.comments.*` |
| coordinate, feed, and spindle precision | `output.precision.*` |
| modal deduplication | `output.duplicates.*` |
| canned-cycle expansion | `processing.translate_drill_cycles` |
| G21/G90/G94 | `postprocessor.properties.preamble` |
| park and stop at end | `postprocessor.properties.postamble` |

## Post overrides

- `_expand_prefix` builds the job-specific M4005 version check, M4000 tool table, G6511 reference probe, G6600 WCS probing, and M7000 VSSC. It also appends the legacy closing sequence: `M9`, `G27`, `M7001`, `M9`, `M5.9`.
- `_convert_tool_change` emits a bare `T` word because firmware services tool changes; `M6` is suppressed.
- `_convert_spindle_command` adds the `.9` wait suffix so RRF blocks until the spindle reaches speed.
- `_convert_fixture` parks before a WCS change, then optionally probes and emits M5011.
- `_convert_coolant_command` labels coolant commands inserted by FreeCAD.
- `_delay_leading_z`, called from `_expand_xy_before_z`, moves a leading Z-only approach after the first XY move.
- `get_sanity_checks` warns about rotary axes, multiple spindles, and disabled version checks.

Compatibility fixes:

- `format_parameter` trims trailing zeros, normalizes `-0`, and supports 26.x base methods with or without the `command_name` argument.
- `_expand_prefix` sets `PARAMETER_ORDER` to match legacy output. It must be set there because `apply_configuration_bundle()` replaces `self.values` during Stage 0.
- `_convert_rapid_move` removes `F` from `G0` and drops rapid moves whose axes were all deduplicated. The base class's `F_FOR_RAPID_MOVES` check is unreachable when `output.duplicates.parameters` is false.
- `_convert_arc_move` removes zero-valued `I`/`J`/`K` offsets, matching legacy output.
- `_convert_modal_command` drops `G80`, `G98`, and `G99`. RRF treats `G83` as one-shot with an explicit `R`; MillenniumOS does not support `G98` or `G99`.
- `_expand_xy_before_z` calls the base implementation first. The base decomposes combined XYZ moves but does not reorder FreeCAD's usual two-move approach, which `_delay_leading_z` handles.

## Approach ordering

FreeCAD commonly emits `G0 Z5` followed by `G0 X.. Y..`. After a tool change, the machine is parked above the toolsetter. Descending before traversing can send the XY move through the toolsetter, so the post defers the leading pure-Z move until after the first XY move.

Only pure-Z moves are deferred; legacy also deferred combined XYZ moves. Any deferred move left at the end of an operation is emitted rather than dropped. The reorder runs during expansion, before axis-word deduplication, and applies regardless of `xy_before_z_after_tool_change`.

## Upstream FreeCAD behavior

FreeCAD 26.3's machine-post API is evolving. The machine post requires the 2026-09-02 weekly build or later.

### Duplicate suppression and tool changes

Before commit [`493bba9e42`](https://github.com/FreeCAD/FreeCAD/commit/493bba9e42), `GcodeProcessingUtils.suppress_redundant_axes_words()` suppressed repeated axes in output text and reset only at `M6`/`M06`. Since this post emits a bare `T` word, that reset was missed and a retract could be suppressed across a tool change. A sentinel-comment workaround was used in the old pipeline.

The command-stage deduplicator now recognizes tool-change commands and `ANNOT_MODAL_BARRIER` before conversion. The string-stage `_optimize_gcode()` hook was also removed; the post's approach reordering now runs in `_expand_xy_before_z`. `_reset_modal_state()` handles the separate conversion-stage suppression pass.

### Coolant commands

FreeCAD hardcodes coolant commands as `M7`/`M07`, `M8`/`M08`, and `M9`/`M09`. A non-standard command such as `M7.1` does not dispatch to `_convert_coolant_command()` or `_expand_coolant_delay()`. Making these constants post-overridable would support non-standard coolant modes.

## Machine-definition details

- FreeCAD inserts `M7`/`M8`/`M9` into the operation path based on `obj.CoolantMode`; the post only labels them.
- On 3-axis machines, many fields (including axis limits, velocity, and coolant properties) are descriptive rather than inputs to posted output. Keep them accurate for the editor, validator, and future versions.
- Spindle `min_rpm` and `max_rpm` are active: FreeCAD clamps speeds to that range and scales feeds to preserve chipload.
- `_make_postable(label, [])` does not create a deduplication barrier. A postable without a path does; an empty `Path` does not.
- `supported_commands` is substring-matched, so `M3` also matches `M30`.
- The `.fcm` validator checks axis limit ordering, kinematic chains, post resolution, property keys, and ignored keys.
- `processing.f_for_rapid_moves` is not read from `.fcm` by this FreeCAD version. `_convert_rapid_move()` enforces the desired behavior directly.
- `processing.filter_inefficient_moves` is currently unused upstream. Keep it `false`; `_optimize_g0()` is not called by `export2()` and `collapse_g0()` has no active caller.
- Command annotations include `ANNOT_MODAL_BARRIER`, `ANNOT_ALLOW_UNSUPPORTED`, and `ANNOT_NO_COLLAPSE_G0`.

## Validation notes

### Legacy comparison

Earlier comparisons across a profiling job, a large adaptive job, and a drilling job found these differences:

- Feed rounding: legacy truncates feed while the base rounds, e.g. `F919` versus `F920`.
- Feed placement: the machine post may emit a standalone `G1 F...` before the next move.
- Modal axes: the machine post omits unchanged axes that the legacy post reasserts; the tested motions were equivalent.
- One extra `M9` before `G27`: this is a no-op when coolant is already off and can be removed from `postprocessor.properties.postamble` for an exact match.

These comparisons predate FreeCAD commit `493bba9e42`, which moved suppression to `Path.Command` objects and changed when approach reordering runs. Re-run the comparisons on a current build before relying on those results.

### Coverage gaps

No job has exercised multiple fixtures/WCSs or probing operations; `_convert_fixture()`'s park-before-change branch and multiline return remain untested. Rotary support is also untested on hardware. The README documents the operational limitations and dry-run guidance.