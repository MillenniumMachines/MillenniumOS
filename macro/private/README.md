# Named Private Macros
These are macros that are not given a G- or M- code, so they cannot be called directly from post-processor output.

This is deliberate, usually because they implement scheduled tasks or other internal functionality that should not become part of the _public_ interface.

These files are moved into the `/sys/mos` folder in the release so they can be called using the relative path `M98 P"mos/macro-name.g"`.