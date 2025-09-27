## Gemini Added Memories
- This project, MillenniumOS, is written in the RRF Meta Gcode language which runs on top of RepRapFirmware 3.6+. It is NIST compatible gcode that has been expanded with various programming concepts like conditionals and loops. The GCodes that RRF implements are here: https://docs.duet3d.com/en/User_manual/Reference/Gcodes and the Meta Gcode constructs and expressions are documented here: https://docs.duet3d.com/User_manual/Reference/Gcode_meta_commands
- There are 3 main components - the macros (in the macro and sys folders), the UI (written as a Vue 2.7 plugin) in the ui folder, and the post processors, in the post-processors folder.
- All features should be implemented in a new feature branch and then merged into the target branch, either via PR if the target is main, or via a merge and push for non protected branches.

---

## RRF Variable Naming Constraints

- All global and local variables used within RepRapFirmware G-code macros must be alphanumeric.
- Special characters, including underscores (`_`) and dashes (`-`), are not permitted in variable names.
