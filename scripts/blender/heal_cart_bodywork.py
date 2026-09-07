"""Armored field ambulance: chamfered cab, service body and detailed wheel rig."""
import math
from pickup_geometry import MeshBuilder
from build_equipment import box, tube, beam

WHEEL_RADIUS = .52
WHEEL_ANCHORS = ((-1.25, -1.15), (-1.25, 1.15), (1.25, -1.15), (1.25, 1.15))


def build():
    b = MeshBuilder()
    box(b, (0,.69,0), (2.58,.23,3.65), 'paint_shadow')
    box(b, (0,1.50,-.58), (2.23,1.55,2.35), 'paint')
    box(b, (0,2.31,-.58), (2.29,.12,2.40), 'paint_light')
    # Raked cab with a short sloped hood, actual windshield pillars.
    b.loft([[(-1.10,-.55,.84),(1.10,-.55,.84),(1.10,-1.63,.84),(-1.10,-1.63,.84)],
            [(-.96,-.55,2.19),(.96,-.55,2.19),(.96,-1.06,2.19),(-.96,-1.06,2.19)]], 'paint')
    box(b, (0,2.24,.86), (2.03,.12,.89), 'paint_light')
    for side in (-1,1):
        # Inset front panes follow the cab rake.
        b.polygon([(side*.07,-1.38,1.50),(side*.91,-1.38,1.50),
                   (side*.86,-1.12,2.09),(side*.07,-1.12,2.09)],'glass',(0,-1,0))
        b.polygon([(side*1.033,-.63,1.52),(side*1.033,-1.32,1.52),
                   (side*.978,-1.10,2.07),(side*.978,-.63,2.07)],'glass',(side,0,0))
        box(b, (side*1.13,1.23,.94), (.045,.41,.66),'paint_shadow')
        box(b, (side*1.17,1.44,.66), (.055,.055,.18),'steel')
        beam(b,(side*1.0,1.69,1.12),(side*1.35,1.69,1.12),.035,'steel')
        box(b,(side*1.38,1.77,1.12),(.08,.22,.17),'trim')
        box(b,(side*1.13,1.72,-.57),(.025,.58,.17),'white')
        box(b,(side*1.15,1.72,-.57),(.025,.17,.62),'white')
        for z in (-1.15,1.15):
            box(b,(side*1.22,1.02,z),(.43,.12,1.21),'paint_light')
            beam(b,(side*.92,.62,z-.20),(side*.92,.97,z+.20),.065,'steel')
        box(b,(side*1.16,.83,.03),(.30,.10,.70),'steel')
        box(b,(side*.84,1.06,1.84),(.28,.23,.06),'trim')
        box(b,(side*.84,1.07,1.883),(.21,.16,.035),'lamp')
        box(b,(side*.86,1.10,-1.80),(.17,.27,.065),'red')
        box(b,(side*.48,1.58,-1.78),(.85,1.10,.055),'paint_light')
        for y in (1.24,1.95):
            box(b,(side*.91,y,-1.82),(.15,.055,.065),'steel')
        box(b,(side*.10,1.62,-1.83),(.045,.17,.035),'trim')
    box(b,(0,.83,1.92),(2.45,.20,.20),'steel')
    box(b,(0,1.10,1.80),(1.13,.35,.09),'dark')
    for x in (-.44,-.22,0,.22,.44):
        box(b,(x,1.10,1.86),(.045,.26,.03),'steel')
    box(b,(0,2.34,.78),(1.21,.07,.28),'trim')
    for x in (-.44,.44):
        tube(b,(x,2.45,.78),.13,.18,'red',segments=12)
        tube(b,(x,2.56,.78),.09,.03,'paint_light',segments=12)
    parts=[('Body',b,(0,0,0))]
    for x,z in WHEEL_ANCHORS:
        w=MeshBuilder()
        tube(w,(0,0,0),WHEEL_RADIUS,.35,'rubber',(1,0,0),16)
        for index in range(20):
            angle=index*math.tau/20
            # Tire lugs remain simple cubes; beveling 80 tiny lugs wastes geometry.
            w.box((0,-math.cos(angle)*.51,math.sin(angle)*.51),(.39,.09,.09),'tread')
        for side in (-1,1):
            tube(w,(side*.185,0,0),.32,.045,'trim',(1,0,0),12)
            tube(w,(side*.215,0,0),.24,.035,'steel',(1,0,0),12)
            tube(w,(side*.24,0,0),.10,.07,'paint_shadow',(1,0,0),10)
            for i in range(6):
                angle=i*math.tau/6
                tube(w,(side*.243,math.sin(angle)*.16,math.cos(angle)*.16),.026,.022,'accent',(1,0,0),6)
        parts.append(('Wheel_'+('L' if x<0 else 'R')+('F' if z>0 else 'B'),w,(x,WHEEL_RADIUS,z)))
    return parts
