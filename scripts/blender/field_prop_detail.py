"""Baked hardware for small military supplies and the factory exterior."""
import math
from build_equipment import box, tube, beam


def mine(b):
    for index in range(8):
        angle=index*math.tau/8
        x,z=math.cos(angle)*.44,math.sin(angle)*.44
        tube(b,(x,.398,z),.035,.035,'steel',segments=6)
    for side in (-1,1):
        box(b,(side*.57,.23,0),(.16,.10,.25),'steel')
        box(b,(side*.63,.23,0),(.035,.04,.11),'dark')
    box(b,(0,.29,.573),(.26,.12,.045),'paint_light')
    box(b,(0,.30,.603),(.14,.045,.018),'trim')


def supply(b, kind):
    if kind=='pickup_fuel':
        for z in (-.17,.17):
            box(b,(0,.52,z),(.44,.66,.025),'paint_shadow')
        for y in (.27,.72):
            box(b,(0,y,.23),(.43,.04,.025),'paint_light')
        tube(b,(.19,1.064,.12),.093,.028,'steel',segments=8)
        for x in (-.22,.22):
            box(b,(x,.89,.23),(.07,.12,.04),'accent')
        box(b,(-.20,.98,0),(.13,.08,.18),'paint_light')
    elif kind=='pickup_salvage':
        for side in (-1,1):
            for z in (-.29,.29):
                box(b,(side*.34,.36,z),(.07,.55,.07),'steel')
        for x in (-.19,.19):
            box(b,(x,.48,.34),(.08,.11,.04),'accent')
        beam(b,(-.24,.76,-.17),(.21,.93,.12),.04,'trim')
        tube(b,(-.20,.80,.13),.14,.06,'paint_light',(1,0,0),8)
        tube(b,(-.237,.80,.13),.085,.012,'dark',(1,0,0),8)


def factory(body, roof):
    # All panels lie on existing walls or under the established roof silhouette.
    for side in (-1,1):
        for y in (1.0,1.35,1.70,2.05,2.40):
            box(body,(side*3.515,y,-.10),(.025,.10,1.35),'trim')
        for z in (-1.60,-.55,.50,1.55):
            tube(body,(side*3.63,2.86,z),.055,.055,'steel',(1,0,0),6)
    for y in (.50,.80,1.10,1.40,1.70,2.00,2.30,2.60):
        box(body,(0,y,3.185),(2.55,.045,.045),'steel')
    for x in (-2.64,-2.08):
        box(body,(x,2.12,3.35),(.065,3.00,.065),'steel')
    for y in (.80,1.10,1.40,1.70,2.00,2.30,2.60,2.90,3.20,3.50):
        box(body,(-2.36,y,3.38),(.62,.045,.045),'steel')
    for x in (-1.20,1.20):
        box(roof,(x,4.06,-.70),(.65,.15,.90),'paint')
        for z in (-.96,-.78,-.60,-.42):
            box(roof,(x,4.15,z),(.50,.025,.055),'trim')
