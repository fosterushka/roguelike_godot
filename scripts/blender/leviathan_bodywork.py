"""Low siege tank, authored from scratch using the common vehicle primitives.

Six batches: hull, two drives, cannon, missile rack and reactor. Roadwheel rims
are built only on the visible side; broad plates replace microscopic bolts.
"""
import json, math
from functools import partial
from pathlib import Path
import bpy
ROOT = Path(__file__).resolve().parents[2]
GEOMETRY = json.loads((ROOT/'data/leviathan_geometry.json').read_text())
TRACK_SEGMENTS = 6
TRACK_SHOE_SPACING = .32
ROAD_WHEELS = 4


def install(api):
    globals().update({key: api[key] for key in ('group','cube','cyl','strut','finish','join_into','hull','panel','vent')})
    globals()['panel'] = partial(api['panel'], bevel=False)


def component(p,kind):
    name='Component_'+kind[0].upper()+kind[1:]
    mesh=bpy.data.meshes.new(name)
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.parent=p;obj.location=GEOMETRY['components'][kind]['anchor']
    return finish(obj,'dark')


def drive(p,side):
    """Closed thick capsule belt, outer wheel hardware only; no under-hull clutter."""
    kind='leftDrive' if side<0 else 'rightDrive'
    target=component(p,kind)
    before=set(p.children)
    x=side*2.15; radius=.62; half=1.72; width=.94; z=.66
    points=[]
    for end,start in ((half,-math.pi/2),(-half,math.pi/2)):
        for i in range(TRACK_SEGMENTS+1):
            a=start+i*math.pi/TRACK_SEGMENTS
            points.append((end+math.cos(a)*radius,z+math.sin(a)*radius))
    vertices=[]
    for xx,r in ((x-width/2,1.0),(x+width/2,1.0),(x-width/2,.86),(x+width/2,.86)):
        for y,zz in points:vertices.append((xx,y,(zz-z)*r+z))
    n=len(points);faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                      (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    mesh=bpy.data.meshes.new('SiegeBelt');mesh.from_pydata(vertices,[],faces);mesh.update()
    belt=bpy.data.objects.new('SiegeBelt',mesh);bpy.context.collection.objects.link(belt);belt.parent=p;finish(belt,'rubber')
    for i in range(ROAD_WHEELS):
        y=-half+i*2*half/(ROAD_WHEELS-1)
        cyl(p,'RoadWheel',(x,y,z),radius*.84,width*.88,'dark',(0,math.pi/2,0),10)
        face=x+side*(width*.5+.02)
        cyl(p,'RoadWheelRim',(face,y,z),radius*.56,.035,'steel',(0,math.pi/2,0),10)
        cyl(p,'AxleCap',(face+side*.025,y,z),radius*.23,.05,'shadow',(0,math.pi/2,0),8)
    for i in range(n):
        a=points[i];b=points[(i+1)%n];length=math.dist(a,b)
        count=max(1,round(length/TRACK_SHOE_SPACING))
        for j in range(count):
            t=(j+.5)/count;y=a[0]+(b[0]-a[0])*t;zz=a[1]+(b[1]-a[1])*t
            shoe=cube(p,'BeltCleat',(x,y,zz),(width*.98,length/count*.38,.06),'steel')
            shoe.rotation_euler.x=math.atan2(b[1]-a[1],b[0]-a[0])
    # A tapered shoulder and overlapping skirt form one removable drive assembly.
    shoulder=hull(p,'TrackShoulder',[(-2.32,.45,1.05,1.28,.08),(-1.76,.55,1.05,1.56,.10),
        (1.68,.55,1.05,1.49,.10),(2.32,.42,1.05,1.23,.08)],'paint');shoulder.location.x=x
    for i in range(4):
        y=-1.50+i*.96
        plate=panel(p,'SuspensionSkirt',(x+side*.44,y,1.13),(.12,.84,.55),'paint')
        plate.rotation_euler.y=side*.13
        panel(p,'SkirtInset',(x+side*.52,y,1.22),(.025,.65,.07),'shadow')
    join_into(target,list(set(p.children)-before))


def cannon(p):
    target=component(p,'gunPod');before=set(p.children)
    cyl(p,'TurretRace',(0,-.40,1.63),1.04,.18,'dark',(0,0,0),12)
    hull(p,'WedgeTurret',[(-1.43,.55,1.69,1.93,.10),(-.65,1.03,1.65,2.34,.14),
        (.39,.94,1.66,2.27,.14),(.75,.59,1.72,1.98,.10)],'paint')
    for side in (-1,1):
        # Long, stepped gun shrouds; dark open muzzle faces read at gameplay scale.
        x=side*.41
        cyl(p,'RecoilCollar',(x,-1.26,1.96),.22,.49,'shadow',vertices=10)
        shroud=hull(p,'GunShroud',[(-3.30,.12,1.85,2.08,.045),(-1.37,.19,1.79,2.14,.06)],'steel');shroud.location.x=x
        muzzle=hull(p,'MuzzleBrake',[(-3.63,.22,1.80,2.13,.06),(-3.22,.17,1.83,2.10,.05)],'shadow');muzzle.location.x=x
        cube(p,'MuzzleOpening',(x,-3.64,1.965),(.27,.017,.17),'dark')
        for offset in (-1,1):cube(p,'MuzzleSlot',(x+offset*.216,-3.45,1.97),(.015,.14,.08),'dark')
        strut(p,'RecoilPiston',(x+side*.23,-1.03,1.91),(x+side*.23,-1.92,1.91),.043,'cream')
        panel(p,'TurretCheek',(side*.92,-.32,2.10),(.12,.64,.30),'light',-.18)
    cyl(p,'CommanderHatch',(-.37,.10,2.31),.24,.055,'shadow',(0,0,0),10)
    cube(p,'GunnerSight',(.34,-.43,2.39),(.29,.24,.12),'dark',.02)
    cube(p,'SightLens',(.34,-.558,2.40),(.19,.017,.045),'red')
    join_into(target,list(set(p.children)-before))


def missile_rack(p,variant):
    target=component(p,'missilePod');before=set(p.children)
    # Two shoulder-mounted pods, attached to a low crossbeam rather than a tower.
    cube(p,'RackCrossbeam',(0,1.12,1.78),(3.26,.36,.17),'shadow',.03)
    for side in (-1,1):
        x=side*1.25
        cyl(p,'RackTrunnion',(x,1.12,1.90),.21,.58,'steel',(0,math.pi/2,0),10)
        shell=hull(p,'MissileCassette',[(.37,.43,1.86,2.41,.08),(1.83,.43,1.80,2.34,.08)],'paint');shell.location.x=x
        cube(p,'LauncherFace',(x,.345,2.13),(.68,.06,.39),'dark',.025)
        # Six readable cells per pod. A shallow rim and black centre, no deep tubes.
        for dx in (-.22,0,.22):
            for zz in (2.015,2.235):
                # One annular face and a recessed black face per cell; no hidden tube walls.
                vertices=[]
                for radius,yy in ((.083,.298),(.063,.298),(.063,.324)):
                    for i in range(8):
                        a=i*math.tau/8
                        vertices.append((x+dx+math.cos(a)*radius,yy,zz+math.sin(a)*radius))
                mesh=bpy.data.meshes.new('LaunchSocket')
                faces=[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
                faces += [(i+8,(i+1)%8+8,(i+1)%8+16,i+16) for i in range(8)]
                faces.append(tuple(range(16,24)))
                mesh.from_pydata(vertices,[],faces);mesh.update()
                obj=bpy.data.objects.new('LaunchSocket',mesh);bpy.context.collection.objects.link(obj);obj.parent=p;finish(obj,'steel')
                uv=obj.data.uv_layers.active
                for face in list(obj.data.polygons)[8:]:
                    for li in face.loop_indices:uv.data[li].uv=(.375,.625)
        panel(p,'CassetteStripe',(x,1.07,2.405),(.10,1.11,.025),'cream',.048)
        for yy in (.70,1.30):panel(p,'PodSideRib',(x+side*.445,yy,2.12),(.026,.05,.35),'shadow')
        if variant=='armored':
            armor=hull(p,'LauncherArmor',[(.24,.47,2.38,2.47,.03),(1.86,.47,2.31,2.40,.03)],'light');armor.location.x=x
            panel(p,'LauncherSideArmor',(x+side*.47,1.06,2.12),(.07,1.30,.43),'paint')
    join_into(target,list(set(p.children)-before))


def reactor(p):
    target=component(p,'core');before=set(p.children)
    cyl(p,'ReactorHousing',(0,1.60,1.64),.53,.33,'shadow',(0,0,0),12)
    cyl(p,'ReactorRing',(0,1.60,1.84),.48,.09,'steel',(0,0,0),12)
    cyl(p,'ReactorCore',(0,1.60,1.90),.35,.025,'amber',(0,0,0),12)
    for i in range(4):
        a=i*math.tau/4
        strut(p,'ReactorRetainer',(.49*math.cos(a),1.60+.49*math.sin(a),1.94),
              (.18*math.cos(a),1.60+.18*math.sin(a),1.94),.034,'dark')
    cube(p,'RearHeatExchanger',(0,2.22,1.22),(.90,.16,.47),'dark',.03)
    for x in (-.33,-.11,.11,.33):cube(p,'HeatExchangerSlot',(x,2.315,1.22),(.09,.018,.29),'amber')
    join_into(target,list(set(p.children)-before))


def build(variant='armored'):
    p=group('boss')
    # Continuous sharply tapered hull, stepped beak and broad sloping shoulders.
    hull(p,'Keel',[(-2.57,.94,.24,.69,.12),(-1.70,1.56,.24,1.08,.15),(1.82,1.55,.24,1.06,.13),(2.38,1.06,.30,.74,.10)],'shadow')
    hull(p,'SiegeHull',[(-2.49,1.11,.64,.95,.10),(-1.40,1.66,.62,1.56,.14),
         (.98,1.67,.63,1.61,.15),(2.31,1.25,.60,1.34,.10)],'paint')
    hull(p,'ArmoredBeak',[(-2.68,.95,.50,.70,.07),(-2.40,1.19,.66,.99,.10),(-1.63,1.49,1.02,1.35,.10)],'light')
    cube(p,'BeakSeam',(0,-2.54,.88),(1.62,.03,.055),'dark')
    for side in (-1,1):
        drive(p,side)
        cheek=hull(p,'NoseCheek',[(-2.42,.24,.86,1.09,.06),(-1.47,.39,1.17,1.49,.08)],'shadow');cheek.location.x=side*1.22
        cube(p,'LampRecess',(side*1.40,-1.83,1.23),(.35,.09,.13),'dark')
        cube(p,'RunningLight',(side*1.40,-1.885,1.24),(.25,.022,.043),'cream')
        strut(p,'RecoveryShackle',(side*.73,-2.63,.54),(side*.73,-2.63,.74),.055,'steel')
        cube(p,'DeckGrille',(side*.76,1.94,1.46),(.46,.41,.035),'dark')
        for yy in (1.81,1.94,2.07):cube(p,'RadiatorLouvre',(side*.76,yy,1.485),(.43,.045,.022),'steel')
        cube(p,'RearTowPoint',(side*.93,2.39,.56),(.20,.12,.16),'steel')
        cube(p,'RearLight',(side*1.10,2.32,1.10),(.18,.025,.07),'red')
        strut(p,'DeckRail',(side*1.66,.50,1.67),(side*1.49,1.88,1.53),.028,'steel')
        if variant=='armored':
            # Three fitted plates per shoulder follow the hull contour.
            for yy in (-.92,-.25,.42):
                plate=panel(p,'ShoulderArmor',(side*1.52,yy,1.50),(.33,.53,.105),'paint')
                plate.rotation_euler.y=side*.22
                panel(p,'ShoulderPlateInset',(side*1.54,yy,1.565),(.20,.39,.018),'shadow')
    cannon(p);missile_rack(p,variant);reactor(p)
    return p
