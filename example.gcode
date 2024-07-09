(Exported by FreeCAD)
(Post Processor: MillenniumOS v0.3.0-rc4-5-g1766cc6-dirty by Millennium Machines)
(Output Time: 2024-06-13 13:38:15.295663+00:00)

(WARNING: This gcode was generated to target a singular firmware configuration for RRF.)
(This firmware implements various safety checks and spindle controls that are assumed by this gcode to exist.)
(DO NOT RUN THIS GCODE ON A MACHINE OR FIRMWARE THAT DOES NOT CONTAIN THESE CHECKS!)
(You are solely responsible for any injuries or damage caused by not heeding this warning!)

(Begin preamble)

(Check MillenniumOS version matches post-processor version)
M4005 V"v0.3.0"

(Pass tool details to firmware)
M4000 P11 R15 S"Boss-Tornado-3F-D30.0-I10.5 Face Mill F=3 L=10.5 CR=0"
M4000 P30 R3 S"ZCD2F-D6.0-R90 Chamfer Mill F=2 L=3.0 CR=0"

(Probe reference surface if necessary)
G6511

(WCS Probing Mode: ON_CHANGE)

(Movement configuration)
G90
G21
G94

(Enable Variable Spindle Speed Control)
M7000 P4000 V200

(Switch to WCS 2)
G55

(Probe origin in current WCS)
G6600

(Enable rotation compensation if necessary)
M5011

(TC: Boss-Tornado-3F-D30.0-I10.5 Face Mill)
T11

(Start spindle at requested RPM and wait for it to accelerate)
M3.9 S18000

(Begin Operation: Flatten Top Surface)
G0 X66.325 Y-51.325

(Delayed Z move following XY)
G0 Z15

G0 Z5
G1 F400 Z-0.75
G1 F1506 Y51.325
...
(Performs a series of cuts ...)

(Park ready for WCS change)
G27

(Switch to WCS 3)
G56

(Probe origin in current WCS)
G6600

(Enable rotation compensation if necessary)
M5011

(TC: ZCD2F-D6.0-R90 Chamfer Mill)
T30

(Start spindle at requested RPM and wait for it to accelerate)
M3.9 S21982

(Begin Operation: Chamfer Outside Lip to Confirm Location)
G0 X-47.65 Y43.5

(Delayed Z move following XY)
G0 Z15

G0 Z5
G1 F400 Z-0.6
G2 F2200 I4.15 X-43.5 Y47.65 Z-0.6
G1 X43.5
G2 J-4.15 X47.65 Y43.5 Z-0.6
G1 Y-43.5
G2 I-4.15 X43.5 Y-47.65 Z-0.6
G1 X-43.5 Y-47.65
G2 J4.15 X-47.65 Y-43.5 Z-0.6
G1 Y43.5
G0 Z15

(Begin postamble)

(Park)
G27

(Disable Variable Spindle Speed Control)
M7001

(Double-check spindle is stopped!)
M5.9