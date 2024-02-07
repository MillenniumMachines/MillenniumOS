# MillenniumOS (MOS) - An "Operations System" for RepRapFirmware.
Cheap and easy manual and automatic work-piece probing, toolchanges and toolsetting and more!

This is an "operations system" rather than an "operating system" in the traditional sense.

We build _on top of_ RepRapFirmware, providing operators of the Millennium Machines Milo V1.5 with a new-machinist-friendly workflow for work piece and tool probing, and safe, effective tool changes.

## Features
  - Canned probing cycles usable directly from gcode or via Duet Web Control as named macros.
  - Fallbacks to guided manual probing when touch probe and / or toolsetter is not available.
  - Safety checks at every step to instill confidence in novice machinists.
  - Variable Spindle Speed Control.
  - Compatible with Millennium Machines Milo GCode Dialect.

## Usage
  - Configure your toolsetter and optionally, touch probe, in RRF. Please see [here](#rrf-config) for instructions.
  - Download the ZIP file of a release.
  - Extract the ZIP file onto the root of your SD card, or upload it to DWC.
  - Add `M98 P"mos.g"` to the bottom of your `config.g` file.
  - Restart RRF (`M999`)
  - Follow the configuration wizard in Duet Web Control that will guide you through the necessary configuration settings.

## Notes
  - You _must_ be using RRF `v3.5.0-rc.2` or above. MOS uses many 'meta gcode' features that do not exist in earlier versions.
  - MOS includes its own `daemon.g` file to implement repetitive tasks, such as VSSC. If you already have a `daemon.g` file, you will need to rename it and include it into the MOS `daemon.g`. This will require modifying your existing code to work smoothly with the MOS `daemon.g`, and is outside of the scope of this documentation. Anything you add to `daemon.g` and any affects it has on the functionality of MOS is unsupported.

## RRF Config
You need to configure your Toolsetter and optionally, Touch Probe, in RRF before trying to use them in MillenniumOS.

This involves configuring both of them as Z probes, which can be done with the `M558` command.

You would add a line similar to these to your RRF `config.g` file, above where the MillenniumOS file (`mos.g`) is included.

```gcode
; Configure the toolsetter as Z-Probe 1 on pin "xstopmax" - mainboard specific, DO NOT COPY AND PASTE!

; Type P8             = unfiltered digital
; Dive Height H10     = back-off 10mm before repeat probing
; Max Retries A10     = retry probe a maximum of 10 times
; Tolerance S0.01     = when tolerance is reached, stop probing
; Travel Speed T1200  = travel moves run at this speed to the start of the probing location
; Probe Speed F300:60 = initial probe speed runs at 300mm/min, subsequent at 60mm/min
M558 K1 P8 C"xstopmax" H10 A10 S0.01 T1200 F300:60

; Configure the touch probe as Z-Probe 2 on pin "probe" - mainboard specific, DO NOT COPY AND PASTE!

; Type P8             = unfiltered digital
; Dive Height H2      = back-off 2mm before repeat probing
; Max Retries A10     = retry probe a maximum of 10 times
; Tolerance S0.01     = when tolerance is reached, stop probing
; Travel Speed T1200  = travel moves run at this speed to the start of the probing location
; Probe Speed F300:50 = initial probe speed runs at 300mm/min, subsequent at 50mm/min
M558 K2 P8 C"probe" H2 A10 S0.01 T1200 F300:50
```

*NOTE*: You must configure at least `A2` on your probes - the first rough probe we perform is not
used to calculate a position, it is just used to find out where subsequent probes should aim for at a lower speed when positions are being recorded.

## Bugs, Issues, Support
If you find any bugs or issues, please report them on this repository. Best-effort support is available via our Discord.

---

## In Depth

### Implemented G- and M- codes
See [GCODE.md](GCODE.md) for a description of all MOS implemented G- and M- codes.

### Post-processor
MOS is designed to work with a specific gcode dialect, designed for the Millennium Machines Milo. It does not support any other gcode dialects.

The following is an example preamble that MOS is designed to understand:

```gcode
(Exported by Fusion360)
(Post Processor: Milo v1.5 by Millennium Machines, version: Unknown)
(Output Time: Thu, 05 Oct 2023 20:03:20 GMT)

(Begin preamble)
(Pass tool details to firmware)
M4000 I2 R1.5 D"3mm Flat Endmill F=1 L=12.0 CR=0.0"
M4000 I3 R3 D"6mm Flat Endmill F=1 L=20.0 CR=0.0"

(Home before start)
G28

(Movement Configuration)
G90
G21

(Prompt operator to insert touch probe before continuing)
M7500

(Probe reference surface for later tool changes)
G6511

(Probe origin corner and save in WCS 3)
G6508 W3

(Prompt operator to remove touch probe before continuing)
M7501

(Switch to WCS 3)
G56

(Enable Variable Spindle Speed Control)
M7000 P2000 V100

(TC: 3mm Flat Endmill L=12)
T2 M6

M3 S19000
G4 S20

(Begin operation adaptive2d: 2D Adaptive1)
(Move to starting position in Z)
G0 Z15.0
...
```
