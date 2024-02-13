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
  - Install one of the post-processors from [here](./post-processors/) into your CAM tool of choice.

## Notes
  - You _must_ be using RRF `v3.5.0-rc.1` or above. MOS uses many 'meta gcode' features that do not exist in earlier versions.
  - If you are using RRF `v3.5.0-rc.2` or below and cannot easily upgrade, you should add `set global.mosProbePositionDelay=350` to the bottom of your `mos-user-vars.g` file after running the Configuration Wizard. There is a bug in v3.5.0-rc.2 and below that causes machine positions to not be reported accurately without at least a 200ms delay after the machine stops moving. This will cause protected probe moves and probe positions to be innaccurate. The simpler fix is just to update RRF.
  - MOS includes its own `daemon.g` file to implement repetitive tasks, such as VSSC. If you want to implement your own repetitive tasks, you should create a `user-daemon.g` file in the `/sys` directory, which MillenniumOS will run during its' own daemon loop. Disabling the MOS daemon tasks will also disable any `user-daemon.g` tasks. Do not use any long-running loops inside `user-daemon.g` as this will interfere with MOS's own daemon behaviour.

## RRF Config
You need a working RRF config with all of your machine axes moving in the right direction before you start.

If you can't home your machine, make that work first - following the MillenniumOS configuration wizard will be impossible without a machine that moves correctly.

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

You will also want to remove any manual tool definitions from your configuration, as MillenniumOS manages tools through the `M4000` and `M4001` custom M-codes - remove any lines in your config.g that use the `M563` command, and also any lines which refer to tools which would have been created by these commands (e.g. `G10 P<toolnumber>`).

## Warnings
Due to a some issues with RRF as it currently stands, there are a small number of situations where you can shoot yourself in the foot when running MillenniumOS macros outside of a print file these are:

 - Clicking Cancel on a messagebox to abort a probing routine may trigger undesired behaviour when running a probe **outside** of a print file. This is because clicking cancel on a message box, if outside of a print, simply returns from the file that created the box. There is no way to easily detect this from any calling macros so we could end up running moves that were unexpected. This is something that ideally will need to be fixed by the RRF devs and is documented [here](https://forum.duet3d.com/topic/34945/meta-gcode-result-variable-inconsistent-with-docs?_=1707734672834). When clicking cancel from _within_ a print, the whole print is aborted from that point so this behaviour should not be an issue when executing actual CAM code produced by our post-processor.

 - Toolchanges cannot currently be cancelled, so if a touch probe is not detected during the touch probe installation routine, then the active tool number will still be set to the probing tool. This will not affect print files because an aborted toolchange aborts the print (but still sets the active tool number). We use the tool number as a guard to not execute probing routines unless the touch probe is installed, so this leaves some window of vulnerability where it could _appear_ like a touch probe is connected when it actually wasn't detected. Again, this is likely something that should be fixed in RRF but if we absolutely _have_ to work around it by tracking touchprobe connectivity ourselves then we can implement this.

## Bugs, Issues, Support
If you find any bugs or issues, please create an issue on this repository. Best-effort support is available via our [Discord](https://discord.gg/ya4UUj7ax2).

### Troubleshooting
To help us work out any issues, please run `M7600 D1` and paste the whole output into any issue you create, or attach with any help request in Discord. This output includes the value of MOS specific variables and also the contents of the RRF object model - specifically the limits, move, sensors, spindles, state and tool keys which are essential for debugging MillenniumOS functionality (or lack thereof).

---

## In Depth

### Implemented G- and M- codes
See [GCODE.md](GCODE.md) for a description of all MOS implemented G- and M- codes.

### Post-processor
MillenniumOS is designed to work with a specific gcode dialect, designed for the Millennium Machines Milo. It does not support any other gcode dialects.

The following is an example gcode style that MOS is designed to understand:

```gcode
(Exported by Fusion360)
(Post Processor: Milo v1.5 by Millennium Machines, version: Unknown)
(Output Time: Thu, 05 Oct 2023 20:03:20 GMT)

(Begin preamble)
(Pass tool details to firmware)
M4000 P2 R1.5 S"3mm Flat Endmill F=1 L=12.0 CR=0.0"
M4000 P3 R3 S"6mm Flat Endmill F=1 L=20.0 CR=0.0"

(Home before start)
G28

(Movement Configuration)
G90
G21
G94

(Probe origin corner and save in WCS 3)
G6508 W3

(Switch to WCS 3)
G56

(Enable Variable Spindle Speed Control)
M7000 P2000 V100

(TC: 3mm Flat Endmill L=12)
T2

(Start spindle and wait for it to accelerate)
M3.9 S19000


(Begin operation adaptive2d: 2D Adaptive1)
(Move to starting position in Z)
G0 Z15.0
...

(Stop spindle and wait for it to decelerate)
M5.9

(End Job)
M0
```
