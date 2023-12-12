# MeRF - *M*ilo *E*xtensions for *R*epRap*F*irmware.
Cheap and easy manual and automatic work-piece probing, toolsetting and more!

## Features
  - Canned probing cycles usable directly from gcode or via the Duet Web Interface as named macros.
  - Fallbacks to guided manual probing when touch probe or tool-setter is not available.
  - Safety checks at every step to instill confidence in novice machinists.
  - Variable Spindle Speed Control.
  - Compatible with Millennium Machines Milo GCode Dialect.

## Implemented G- and M- codes
See [GCODE.md](GCODE.md) for a description of all MeRF implemented G- and M- codes.

## Post-processor
MeRF is designed to work with a specific gcode dialect, built around the Millennium Machines Milo. It does not support any other gcode dialects.

## Usage
  - Download the ZIP file of a release.
  - Copy the folder structure to the root of your SD card.
  - Add `M98 P"merf.g"` to the bottom of your `config.g` file.

## Notes
  - You _must_ be using RRF `v3.5.0-rc.1` or above. MeRF uses many 'meta gcode' features that do not exist in earlier versions.
  - MeRF includes its' own `daemon.g` file to implement repetitive tasks, such as VSSC. If you already have a `daemon.g` file, you will need to rename it and include it into the MeRF `daemon.g`. This will require modifying your existing code to work smoothly with the MeRF `daemon.g`.

## Bugs, Issues, Support
If you find any bugs or issues, please report them on this repository. Best-effort support is available via our Discord.
