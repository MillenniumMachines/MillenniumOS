(Send tool details to RRF)
M4000 P2 R1.5 S"3mm Flat Endmill F=1 L=12.0 CR=0.0"
M4000 P3 R3 S"6mm Flat Endmill F=1 L=20.0 CR=0.0"

(Movement Configuration)
G90
G21
G94

(Home and Park)
G28
G27

(Probe work offset 3)
G6600 W3

(Switch to work offset 3)
G56

(Change to 3mm flat endmill)
T2

(Start spindle at 10k RPM and wait)
M3.9 S10000

(Move to zero position in XY from Park)
G0 X0 Y0

(Move down to zero position in Z)
G0 Z0

(Fake cutting moves)
while { iterations < 5 }
    G0 X-10
    G0 X10
    G0 X0
    G0 Y-10
    G0 Y10
    G0 Y0


(Switch to 6mm flat endmill)
T3

(Start spindle at 10k RPM and wait)
M3.9 S10000

(Move to zero position in XY from Park)
G0 X0 Y0

(Move down to zero position in Z)
G0 Z0

(Fake cutting moves)
while { iterations < 5 }
    G0 X-10
    G0 X10
    G0 X0
    G0 Y-10
    G0 Y10
    G0 Y0

(Probe work offset 4)
G6600 W4

(Switch to work offset 4)
G57

(Switch to 3mm flat endmill)
T2

(Start spindle at 10k RPM and wait)
M3.9 S10000

(Fake cutting moves)
while { iterations < 5 }
    G0 X-10
    G0 X10
    G0 X0
    G0 Y-10
    G0 Y10
    G0 Y0

(Raise tool)
G0 Z10

(Park)
G27

(End Program)
M0