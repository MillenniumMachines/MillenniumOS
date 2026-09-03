# MillenniumOS FreeCAD post — machine-based flow

A port of the MillenniumOS FreeCAD post processor onto the CAM machine-post API in FreeCAD 26.3, alongside machine definitions for Milo and Miley V2.0.

The legacy post is kept, renamed, and still works. Both can be installed at the same time so their output can be compared on the same job.

## Files

| File | Post name in FreeCAD | Purpose |
|---|---|---|
| `millennium_os_legacy_post.py` | `millennium_os_legacy` | the original post, unchanged behaviour |
| `millennium_os_machine_post.py` | `millennium_os_machine` | machine-flow port |
| `machines/Miley_V2.fcm` | — | Miley V2.0 machine definition |
| `machines/Milo_V2.fcm` | — | Milo V2.0 machine definition |
| `machines/Milo_V1.5.fcm` | — | Milo V1.5 machine definition |
| `tools/compare_gcode.py` | — | semantic diff between the two posts' output |

---

## Installing in FreeCAD

1. **Post processors** → copy both `.py` files into a directory on FreeCAD's post search path. The macro directory is the usual choice: `~/.local/share/FreeCAD/v<version>/Macro/`.

   The search order is FreeCAD's `defaultFilePath()`, then `macroFilePath()`, then addon post directories, then FreeCAD's own `Path/Post/scripts/`. **NOTE: The first match wins**, so an older copy in the CAM default file path may silently shadow the one you just installed. If there is reason to have concerns here, to check which file is actually loaded run the code below in FreeCAD's Python console :

   ```python
   import os, Path.Preferences as PP
   print("\n".join(("WINS " if os.path.exists(os.path.join(p, "millennium_os_machine_post.py")) else "  -  ")
                   + os.path.join(p, "millennium_os_machine_post.py") for p in PP.searchPathsPost()))
   ```

2. **Substitute the version.** Both posts contain `%%MOS_VERSION%%`, a build-time placeholder that gets replaced when a release is done on GitHub. Replace it in the *installed* copies with the MillenniumOS version in firmware, e.g. `v0.5.0`. The machine post raises an error rather than emitting a bad `M4005` if you forget. Failing to do this step may result in a CAM job that cannot be executed as MOS checks this when running a job. One note, the machine-based post-processing path will use the `mos_version` in the machine definition first if found.

3. **Machine definitions** → copy the `.fcm` files into `<CAM asset path>/Machines/`. The default asset path is `FreeCAD.getUserAppDataDir()/CamAssets`; check yours with `Path.Preferences.getAssetPath()`.

4. **Restart FreeCAD**. You can confirm classification of post-type (in the FreeCAD Python console):

   ```python
   import Path.Preferences as P
   P.classifyPostProcessor("millennium_os_machine")   # -> 'machine'
   P.classifyPostProcessor("millennium_os_legacy")    # -> 'legacy'
   ```

   If the machine post reports `unknown`, the module raised on import and the classifier swallowed the traceback. The 26.3 machine post path is a rapidly moving target, so entirely possible this breaks due to FreeCAD changes during the development cycle.

5. **In the CAM Job**, set Machine to `Milo V1.5`, `Miley V2.0` or `Milo V2.0`. The postprocessor comes from the machine definition, not the job.

6. **Set `mos_version`** in the machine definition to match your firmware. The machine post reads it from there, not from `RELEASE.VERSION`, so it must be correct or `M4005` will check the wrong version. The machine definitions included here default to v0.5.0.

---

## What the base class does now

Removed from the port because the base `PostProcessor` handles it, driven by the machine definition:

| Legacy behaviour | Now controlled by |
|---|---|
| argparse options | property schema, edited in the Machine editor |
| header block | `output.header.*` |
| comment formatting | `output.comments.*` |
| coordinate / feed / spindle precision | `output.precision.*` |
| modal deduplication | `output.duplicates.*` |
| canned cycle expansion | `processing.translate_drill_cycles` |
| G21/G90/G94 | `postprocessor.properties.preamble` |
| park and stop at end | `postprocessor.properties.postamble` |

## What the port overrides, and why

MillenniumOS-specific:

- **`_expand_prefix`** — M4005 version check, M4000 tool table, G6511 reference probe, G6600 WCS probing, M7000 VSSC. Job-dependent (needs the tool list and the set of used WCSs), so it cannot be a static preamble string. Also appends the closing sequence so the order matches legacy: `M9`, `G27`, `M7001`, `M9`, `M5.9`.
- **`_convert_tool_change`** — emits a bare `T` word; MillenniumOS services the change in firmware, so `M6` is suppressed.
- **`_convert_spindle_command`** — appends the `.9` wait suffix (`M3.9`, `M5.9`) so RRF blocks until the spindle is at speed.
- **`_convert_fixture`** — park before a WCS change, optional probe, M5011.
- **`_convert_coolant_command`** — adds the descriptive comment. The M-codes themselves come from `Path/Op/Base.py`, not from the post (see below).
- **`get_sanity_checks`** — warns on rotary axes, multiple spindles, and a disabled version check.

Compatibility and correctness fixes, each traced to a specific base-class behaviour:

- **`format_parameter`** — strips trailing zeros and normalises `-0` to `0`, so output reads `X141.5` / `F1096` rather than `X141.500` / `F1096.0`. Also tolerates the base method existing with or without the `command_name` argument, which differs between 26.x builds.
- **`init_values` / `_expand_prefix`** — sets `PARAMETER_ORDER` alphabetically to match legacy (`G3 F1096 I-8.839 J3.712 X141.5 Y-51`); the base default reorders every motion line. Set in `_expand_prefix` because `apply_configuration_bundle()` resets `self.values` wholesale in Stage 0.
- **`_convert_rapid_move`** — strips `F` from `G0`, and drops a rapid whose axis words were all removed as unchanged. The base's `F_FOR_RAPID_MOVES` check sits in the `elif` of the duplicate-parameter test, so it is unreachable when `output.duplicates.parameters` is false.
- **`_convert_arc_move`** — drops zero-valued `I`/`J`/`K`. The legacy post marked arc offsets `Control.NONZERO`; without this every G17-plane arc carries `K0`.
- **`_convert_modal_command`** — drops `G80`, `G98`, `G99`. See below.
- **`_convert_item_commands` / `_optimize_gcode`** — per-operation axis-word suppression. See below.

---

## Two upstream FreeCAD issues worth being aware of

### 1. Suppressing M6 disables the only modal reset

FreeCAD's `GcodeProcessingUtils.suppress_redundant_axes_words()` tracks position across the whole G-code body and resets **only** on a line starting with `M6`/`M06`:

```python
if any(stripped.startswith(cmd) for cmd in ["M6", "M06"]):
    current_pos = {k: None for k in current_pos}
```

This post suppresses `M6` because MillenniumOS services tool changes in firmware from a bare `T` word. So the reset never fires, position is tracked straight through a park and tool change, and a retract such as `G0 Z5` at the start of an operation is dropped as redundant — leaving a bare `G0` and **no retract before the following XY rapid**. It affects any post that delegates tool changes to firmware, and it is invisible in the output.

Worked around here by emitting a sentinel comment at each operation, tool-change and fixture boundary, splitting the body on it, suppressing each segment independently, then calling the base with suppression disabled. A proper upstream fix would reset on a bare `T` word too, or expose an overridable reset hook.

Note the legacy post avoids this entirely by calling `_forceAll()` in `onoperation()`, `ontoolchange()` and `onfixture()`.

### 2. Coolant M-codes are hardcoded

FreeCAD's `Constants.py` hardcodes the coolant on/off commands:

```python
MCODE_COOLANT_MIST  = ["M7", "M07"]
MCODE_COOLANT_FLOOD = ["M8", "M08"]
MCODE_COOLANT_OFF   = ["M9", "M09"]
```

A non-standard mode such as an `M7.1` air blast will not dispatch to `_convert_coolant_command()` and will not be seen by `_expand_coolant_delay()`. Widening those constants, or making them post-overridable, would help any post with a non-standard coolant mode.

---

## Things that are not what they look like

Worth knowing before changing anything here.

- **Coolant M-codes come from FreeCAD, not the post.** `Path/Op/Base.py` inserts `M7`/`M8`/`M9` into the operation's Path around the first and last `GCODE_MOVE`, based on `obj.CoolantMode`. The post only labels them. This is why the stock MillenniumOS post contains no coolant code at all and still produces correct coolant output.
- **Most machine-definition fields are descriptive only.** Grepping the CAM module, nothing outside the model class and the Machine editor reads axis `limits`, `max_velocity`, `role`, `parent`, `coolant_flood` or `coolant_mist` for a 3-axis machine. The rotary path generators are the only consumers. Fill them in accurately anyway — a future release may start using them.
- **The spindle `min_rpm`/`max_rpm` are not descriptive.** `Path/Tool/FeedsSpeeds/resolver.py` clamps the calculated speed into that range and scales feeds by the same ratio to hold chipload constant. Raising `min_rpm` therefore raises feeds for anything that lands on the floor.
- **`_make_postable(label, [])` is not a dedup barrier.** It builds an item with a non-`None` but empty `Path`, so `_edit_command_list()` takes the `if item.path` branch, iterates zero commands and never calls `edit_fn`.
- **`supported_commands` is substring-matched.** `convert_command_to_gcode()` does `command.Name not in supported` where `supported` is a newline-joined *string*, so `M3` matches inside `M30`.

---

## Machine definition settings

These are not defaults, and each was arrived at by comparing output against the legacy post. `deploy.sh` refuses to install a definition that reverts any of them.

| Setting | Value | Why |
|---|---|---|
| `processing.filter_inefficient_moves` | `false` | `collapse_g0()` removed ~1500 rapids on a test job, including the XY approach before every operation |
| `processing.translate_drill_cycles` | `false` | MillenniumOS implements G73/G81/G83 natively |
| `processing.f_for_rapid_moves` | `false` | legacy emits no `F` on `G0` |
| `output.duplicates.commands` | `true` | means "emit the command word every line"; `false` suppressed the `M4000` prefix on repeated lines, producing bare parameter lines RRF would reject |
| `output.duplicates.parameters` | `false` | suppress unchanged axis words, as legacy does |
| `output.comments.symbol` | `"("` | `;` produces a file mixing both styles |
| `output.precision.feed` | `0` | legacy truncates feed to whole mm/min |
| `output.precision.axis` | `3` | matches legacy `{:0.3f}` |
| `toolheads[0].toolhead_wait` | `0.0` | `M3.9` already blocks; a `G4` dwell would double the wait |

Axis limits and feedrates come from RRF `M208` and `M203`. Miley is set to the configured soft limits (305 X, 200 Y, 120 Z), not nominal travel. Milo carries nominal travel (348 X, 210 Y) and **should be replaced with real `M208` values** before use.

---

## Verifying against the legacy post

Post the same job through both, then:

```sh
tools/compare_gcode.py legacy.gcode machine.gcode
```

It normalises line numbers, comments, whitespace, parameter order and numeric precision, then compares command by command, so a clean run means behavioural equivalence rather than textual equivalence.

### Known remaining differences

All benign, verified across three jobs (5-tool profiling, a 107k-line adaptive job, and a drilling job):

- **Feed rounding.** Legacy does `int(qty.getValueAs('mm/min'))`; the base rounds. `F919` vs `F920`, about 0.1% on one feed.
- **Feed placement.** The machine post may emit `G1 F920` on its own line where legacy folds the feed into the following move. Both legal.
- **Modal axis words.** The machine post omits an axis word whose value has not changed (`G3 I-1 X29.626`); legacy re-asserts it via `_forceArcParams` / `_forceLinearParams`. Verified equivalent — same motion.
- **One extra `M9`** before `G27`. Legacy's pre-park coolant-off is conditional on coolant being on; this one is unconditional. A no-op when coolant is already off. Remove `M9` from `postprocessor.properties.postamble` for an exact match.
- **Approach ordering.** Legacy defers the Z move (`G0 X.. Y..` then `G0 Z5`); the machine post keeps FreeCAD's order (`G0 Z5` then `G0 X.. Y..`). Same endpoint; retracting before traversing is the safer order.

### Not yet covered

No test job has exercised **multiple fixtures/WCSs** or **probing operations**. `_convert_fixture()`'s park-before-change branch and its multiline return have never run. Treat those as untested.

---

## Before you cut

Dry-run the first real job above the work.
