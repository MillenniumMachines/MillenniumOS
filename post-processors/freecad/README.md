# MillenniumOS FreeCAD Machine Post

Adds a machine-based post for FreeCAD 26.3 and machine definitions for Milo V1.5, V1.6 beta, V2.0, and Miley V2.0. The existing post remains available as the legacy post; both can be installed together and compared on the same job.

The machine post requires a FreeCAD 26.3 weekly build from 2026-09-02 or later. For FreeCAD 1.0 or 1.1, only use the legacy post - the machine-based post pathway is not present in those version.

## Files

| File | Post name in FreeCAD | Purpose |
|---|---|---|
| `millennium_os_legacy_post.py` | `millennium_os_legacy` | the original post, unchanged behaviour |
| `millennium_os_machine_post.py` | `millennium_os_machine` | machine-flow port |
| `machines/*.fcm` | — | machine definitions, see below |
| `tools/compare_gcode.py` | — | semantic diff between the two posts' output |
| `tools/post_cli.py` | — | post a job to G-code headlessly, without the GUI |

### Included machine definitions

| File | Machine name | Travels (X/Y/Z) | Rapids (X/Y/Z) |
|---|---|---|---|
| `machines/Milo_V1.5.fcm` | Milo V1.5 | 340 / 160 / 120 | 2000 / 2000 / 1000 |
| `machines/Milo_V1.6.fcm` | Milo V1.6 beta | 300 / 160 / 120 | 2000 / 2000 / 1000 |
| `machines/Milo_V2.0.fcm` | Milo V2.0 | 348 / 210 / 120 | 2000 / 2000 / 1000 |
| `machines/Miley_V2.0.fcm` | Miley V2.0 | 308 / 210 / 120 | 2000 / 2000 / 1000 |
| `machines/Milo_V1.5_Rotary.fcm` | Milo V1.5 + Rotary | 340 / 160 / 120 | 2000 / 2000 / 1000 |
| `machines/Milo_V1.6_Rotary.fcm` | Milo V1.6 beta + Rotary | 300 / 160 / 120 | 2000 / 2000 / 1000 |
| `machines/Milo_V2.0_Rotary.fcm` | Milo V2.0 + Rotary | 348 / 210 / 120 | 2000 / 2000 / 1000 |

**Every number in these files is a nominal starting point, not a measurement.** Travels are the published figures, quoted minus endstop; your `M208` soft limits will sit a few mm inside them and hard limits may vary based on your build. Rapids are the published V1.5 figures, used for all four because no rapid speed is published for V2 — yours will depend on motors, drive voltage and whether you fitted leadscrews or ballscrews. The stock LDO spindle is described as 1.5 kW running 7200–24000 rpm, but this is just one common configuration among the many possible. **You will need to adjust these for your machine!**

There is deliberately **one definition per machine rather than one per possible configuration** (with the exception of the Spit Roast configs described below). Power, rpm range, cooling, motors and drive voltage all vary between builds, and no useful number of shipped variants would cover that. Copy the definition matching your machine and edit it to fit — see the next section.

### The Spit Roast definitions

The `_Rotary` variants add an **A axis about X** for the Spit Roast 4th axis. They are
separate files rather than an option on the existing ones, because the FreeCAD base class emits a
rotary positioning move for every pose change as soon as a rotary axis exists in the machine def — adding A
to the shipped definitions would change the G-code every existing 3-axis user gets.

A-axis figures come from the MosFourthAxis plugin's `rotary-plugin-config.g` and are
nominal in the same way as everything else here:

| | Value | From |
|---|---|---|
| Limits | ±3600° | `M208 A-3600 / A3600` |
| Max velocity | 45000 °/min | `M203 A45000` |
| Acceleration | 300 °/s² | `M201 A300` (not carried into the `.fcm`) |
| Steps/degree | 177.7919 | `M92 A177.7919` |

`kinematics.rotation_strategy` is `dwo`. That is the only strategy the base class can
actually emit for a control with no tilted-work-plane command, and what it emits is a
plain `G0 A<angle>` with the path already rotated into the machine frame — exactly what
the Fusion post does. RRF has no `G68.2`, so `twp` is not an option, and `post_transform`
is declared upstream but unimplemented. (Note RRF's `G68` is a 2D rotation about Z, used
for tramming compensation — not a tilted work plane.)

`pre_rotary_move` is `G53 G0 Z0`, so Z retracts to machine zero before any rotation. **No
X retract is set.** The Fusion post defaults its X retract to disabled too, and a safe X
is a per-setup value you have to verify against your own fixture; its reference figure is
X=54 on a V1.5. Add it to `pre_rotary_move` if you want it.

**Three limitations worth knowing before you cut:**

- **Indexed (3+1) only.** Continuous 4-axis needs inverse-time feed (`G93`). RRF has
  supported `G93` since 3.5, and FreeCAD has a continuous op (`Path/Op/RotarySurface.py`),
  but FreeCAD's post pipeline never emits `G93` — `GCODE_FEED_INVERSE_TIME` exists only in
  its modal-command lists. A continuous path would come out with a units-per-minute feed
  on a move that is mostly rotation.
- **Work zero must sit on the rotary centreline.** Nothing applies a pivot offset, so
  rotation only leaves the WCS valid if the origin is on the axis of rotation. Probe it
  with `M4910`.
- **Untested on hardware.** No posted rotary job has been cut. Dry-run above the work.

**V1.6 is beta.** Its travels and rapids are inherited from V1.5. The XY and Z plates and anti-backlash block differ, so verify limits against your machine's `M208` before use.The XY and Z plates and the anti-backlash block are new compared to 1.5 and result in some workarea changes, so verify the limits!

---

## Check these against your machine

A `.fcm` is plain JSON and can be edited in a text editor or through the CAM Machine editor in FreeCAD (under Preferences->CAM->Assets). Either way FreeCAD re-reads the file on every post, so changes take effect on the next job with no restart. There is also a new validator in the machine editor that will check for common errors.

### These change the G-code

Get these right before cutting.

| Field | Where it comes from | What goes wrong if it is off |
|---|---|---|
| `machine.toolheads[0].min_rpm` | spindle rating / VFD parameters | FreeCAD's `Path/Tool/FeedsSpeeds/resolver.py` clamps any calculated speed up to this floor **and scales feeds by the same ratio** to hold chipload. A floor set too high silently raises your feeds; too low lets the spindle run where it has neither cooling nor torque |
| `machine.toolheads[0].max_rpm` | as above | speeds above it are clamped down, again rescaling feeds |
| `postprocessor.properties.mos_version` | the MillenniumOS version in firmware | `M4005` fails and the job will not run |

The shipped floor of 7200 rpm assumes an **air-cooled** spindle, where the shaft fan gives least airflow exactly when torque demand is highest. A water-cooled spindle has no such constraint and can usually take a considerably lower floor — 6000 or below. If you have changed spindle, this is the first field to revisit. **Always check your values here, these are generic common limits in the provided files, but your mileage may vary and getting this wrong can cause damage to your spindle!**

### These should be accurate but do not affect output today

On 3-axis machines, these values do not affect posted G-code. The validator still checks axis limits and reports ignored keys, so keep the values accurate for the Machine editor and future FreeCAD versions.

| Field | Where it comes from |
|---|---|
| `machine.axes.X/Y/Z.limits.min` and `.max` | RRF `M208` — your configured soft limits, usually a few mm inside nominal travel |
| `machine.axes.X/Y/Z.max_velocity` | RRF `M203` — varies with motors, drive voltage and leadscrew versus ballscrew, so two nominally identical machines can differ |
| `machine.toolheads[0].max_power_kw` | spindle manufacturer's docs |
| `machine.toolheads[0].coolant_mist` / `coolant_flood` | whether you run air blast, mist or flood (note: air as distinct cooling mode not currently supported in FreeCAD machine posts)|

>**Note**: `limits.min` must be strictly less than `limits.max` or the definition fails validation.

To read the firmware values, send `M208` and `M203` with no parameters in the MOS console. `M203` takes and reports mm/min, which is what the `.fcm` wants — but the object model (`M409 K"move.axes[0]"`) reports `speed` in mm/s, so multiply by 60 if you read it that way. Also check whether your `config.g` pulls in sub-files with `M98 P"..."`; the values you want may not be in the main file.

### Workflow preferences, not machine facts

These sit in `postprocessor.properties` and are yours to set: `probe_mode` (`AT_START`, `ON_CHANGE`, `NONE`), `home_before_start`, `vssc` with `vssc_period` and `vssc_variance`, `output_tools`, `output_job_setup`, and `allow_zero_rpm`. The shipped values are `ON_CHANGE` probing, homing on, VSSC on at 4000 ms / 200 rpm. Change these to match your needs!

One field is deliberately zero and worth understanding before changing: `toolheads[0].toolhead_wait` is `0.0` because this post emits `M3.9`, which already blocks until the spindle reaches speed. Setting it non-zero adds a `G4` dwell on top, so you would wait twice. Raise it only if your spindle genuinely does not reach speed by the time `M3.9` returns (if you've run the MOS config wizard, this should not be the case).

### Leave these alone unless you know why

Everything in the "Machine definition settings" table below was arrived at by diffing output against the legacy post, and several break the G-code if reverted — `duplicates.commands` strips the command word off `M4000` lines, and `filter_inefficient_moves` deletes rapids whenever upstream wires it back up. That section (below) gives the reason for each.

---

## Installing in FreeCAD

1. **Post processors** → copy both `.py` files into a directory on FreeCAD's post search path. The macro directory is the usual choice: on Linux here `~/.local/share/FreeCAD/v<version>/Macro/`. You can also find this by opening the FreeCAD Macros dialog (in the menu Macro->Macros). The path is shown in the User Macros Location at the bottom of the dialog (see below for example):
![FreeCAD Execute Macro dialog](/post-processors/freecad/media/image.png)

   The search order is FreeCAD's `defaultFilePath()`, then `macroFilePath()`, then addon post directories, then FreeCAD's own `Path/Post/scripts/`. **NOTE: The first match wins**, so an older copy in the CAM default file path may silently shadow the one you just installed. If there is reason to have concerns here, to check which file is actually loaded run the code below in FreeCAD's Python console :

   ```python
   import os, Path.Preferences as PP
   print("\n".join(("WINS " if os.path.exists(os.path.join(p, "millennium_os_machine_post.py")) else "  -  ")
                   + os.path.join(p, "millennium_os_machine_post.py") for p in PP.searchPathsPost()))
   ```

2. **Substitute the version.** Both posts contain `%%MOS_VERSION%%`, a build-time placeholder that gets replaced when a release is done for MOS on GitHub. Replace it in the *installed* copies on your computer with the MillenniumOS version in firmware, e.g. `v0.5.0` unless a release is done in the future with this post (in that case, grab from the releases). The machine post raises an error rather than emitting a bad `M4005` if you forget. Failing to do this step may result in a CAM job that cannot be executed as MOS checks this when running a job. One note, the machine-based post-processing path will use the `mos_version` in the machine definition first if this value is found (which nicely circumvents this pain).

3. **Machine definitions** → copy the `.fcm` files into `<CAM asset path>/Machines/`. Check the values against your own machine first — see "Check these against your machine". The default asset path is `FreeCAD.getUserAppDataDir()/CamAssets`; check yours with `Path.Preferences.getAssetPath()`. 

> **Note**: This path can also be configured, I'd recommend creating a repo for your CAM assets and configuring this folder accordingly in FreeCAD if you have the ability to do this. This way you can version control not just the machine assets but also any FreeCAD tool bits you've set up. Especially worth doing if you work on multiple computers.

4. **Restart FreeCAD**. Optionally, you can confirm classification of post-type (in the FreeCAD Python console):

   ```python
   import Path.Preferences as P
   P.classifyPostProcessor("millennium_os_machine")   # -> 'machine'
   P.classifyPostProcessor("millennium_os_legacy")    # -> 'legacy'
   ```

   If the machine post reports `unknown`, the module raised an exception on import and FreeCAD may have swallowed the traceback. The 26.3 machine post path is a rapidly moving target, so entirely possible this breaks due to FreeCAD changes during the development cycle.

5. **In the CAM Job**, set Machine to the entry matching your machine, e.g. `Miley V2.0`. The postprocessor comes from the machine definition, not the job. This can be set in the Job settings panel in the General tab or in the job properties view.
   

6. **Make sure that `mos_version` is correct** in the machine definition to match your firmware. The machine post reads it from there, not from `RELEASE.VERSION`, so it must be correct or `M4005` will check the wrong version. The machine definitions included here default to v0.5.0.

---

## Posting from the command line

`tools/post_cli.py` posts CAM jobs without opening the GUI. It finds a FreeCAD console binary and re-executes itself under FreeCAD.

```sh
# list jobs and installed machines
tools/post_cli.py --list job.FCStd

# post with this checkout's post and machine definition
tools/post_cli.py job.FCStd -M machines/Milo_V1.6.fcm -o out.gcode

# post with the legacy processor
tools/post_cli.py job.FCStd -p millennium_os_legacy -o legacy.gcode
```

### Choosing which job to post

A document with several jobs posts all of them unless told otherwise. `-j` accepts a job label or object name and can be repeated:

```sh
# both jobs -> bookmark_Top.gcode and bookmark_Bottom.gcode
tools/post_cli.py bookmark.FCStd -M machines/Milo_V1.6.fcm -o bookmark.gcode

# just one, written to exactly the name given
tools/post_cli.py bookmark.FCStd -j Top -M machines/Milo_V1.6.fcm -o top.gcode

# a subset
tools/post_cli.py bookmark.FCStd -j Top -j Bottom -M machines/Milo_V1.6.fcm -o out.gcode
```

The output name is only decorated when one run produces more than one file, so
a single `-j` gives you exactly the `-o` path. When several files are written
the job label is appended, sanitised for the filesystem.

The internal object name (`Job`, `Job001`) is also accepted, which is how you
disambiguate if two jobs somehow share a label. An unmatched `-j` lists the
labels that do exist and exits non-zero, as does any other failure — so a CI
step will fail rather than quietly producing nothing.

Two things make this useful for testing rather than just convenient:

- **`--post-dir`** is prepended to FreeCAD's post search path, and defaults to
  this repo. `searchPathsPost()` normally puts the user Macro directory first,
  so without this a run would silently exercise whatever was last synced there
  instead of the working tree.
- **`-M/--machine-file`** loads a `.fcm` straight off disk and injects it into
  the processor, bypassing the asset store. Together with `--post-dir` a run
  touches no installed copy of either half of the post.

Jobs are recomputed before posting, so toolpaths are regenerated rather than
read from whatever was cached in the document.

FreeCAD is located in this order: `$FREECADCMD`, the newest weekly AppImage in
`~/Downloads`, then `freecadcmd` on `PATH`. Make sure the selected build meets
the requirement above; stable FreeCAD 1.1 lacks the `Machine` module.

```sh
FREECADCMD=~/Downloads/FreeCAD_weekly-2026.09.16-Linux-x86_64.AppImage \
    tools/post_cli.py job.FCStd -M machines/Milo_V1.6.fcm -o out.gcode
```

---

## Verifying against the legacy post

Post the same job through both, then:

```sh
tools/compare_gcode.py legacy.gcode machine.gcode
```

Both can be generated headlessly:

```sh
tools/post_cli.py job.FCStd -p millennium_os_legacy      -o legacy.gcode
tools/post_cli.py job.FCStd -M machines/Milo_V1.6.fcm    -o machine.gcode
tools/compare_gcode.py legacy.gcode machine.gcode
```

It normalises line numbers, comments, whitespace, parameter order and numeric precision, then compares command by command, so a clean run means behavioural equivalence rather than textual equivalence.

The comparison tool ignores formatting differences and compares commands and numeric values. A clean result establishes equivalence for that job only, not hardware safety. Detailed known differences and coverage gaps are in [DEVELOPMENT.md](DEVELOPMENT.md#validation-notes).

---

## Before you cut

After a tool change, the post moves to XY while still at park height, then descends to clearance to avoid traversing through the toolsetter. The post has been tested on over a dozen jobs, but not every machine and configuration. **Dry-run your first job above the workpiece and verify clearance.**
