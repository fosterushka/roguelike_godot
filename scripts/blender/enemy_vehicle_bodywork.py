"""Purpose-built vehicle silhouettes and rigid damaged variants.

All geometry is authored before palette batching. Existing wheels, weapon and
Leviathan component names remain the runtime animation/collision contract.
"""
import math
import bpy
from mathutils import Vector

TRACK_SEGMENTS = 6
TRACK_SHOE_SPACING = .24


def install(api):
    globals().update({key: api[key] for key in ('group','cube','cyl','disc','strut','wheel','finish','join_into')})


def hull(p,name,rings,color='paint'):
    """Loft chamfered cross-sections along the vehicle, never a scaled box."""
    vertices=[]
    for y,w,bottom,top,chamfer in rings:
        vertices.extend([(-w+chamfer,y,bottom), (w-chamfer,y,bottom),(w,y,bottom+chamfer),(w,y,top-chamfer),(w-chamfer,y,top),(-w+chamfer,y,top),(-w,y,top-chamfer),(-w,y,bottom+chamfer)])
    faces=[tuple(reversed(range(8)))]
    for i in range(len(rings)-1):
        for j in range(8): faces.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
    faces.append(tuple(range((len(rings)-1)*8,len(rings)*8)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=p
    return finish(obj,color)


def surface(p,name,loc,size,color,axis,sign=1):
    """One outward UV face for markings, inset panels and track ribs."""
    tangent = [i for i in range(3) if i != axis]
    vertices = []
    for u, v in ((-1,-1),(1,-1),(1,1),(-1,1)):
        point = [0.0, 0.0, 0.0]
        point[axis] = sign * size[axis] * .5
        point[tangent[0]] = u * size[tangent[0]] * .5
        point[tangent[1]] = v * size[tangent[1]] * .5
        vertices.append(point)
    normal = (Vector(vertices[1])-Vector(vertices[0])).cross(Vector(vertices[2])-Vector(vertices[0]))
    face = (0,1,2,3) if normal[axis] * sign > 0 else (3,2,1,0)
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], [face]); data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj); obj.parent = p; obj.location = loc
    return finish(obj, color)


def panel(p,name,loc,size,color='paint',angle=0,bevel=False):
    if color == 'glass':
        axis = min(range(3), key=lambda i: size[i])
        sign = (1 if loc[0] > 0 else -1) if axis == 0 else -1
        obj=surface(p,name,loc,size,color,axis,sign)
    else:
        obj=cube(p,name,loc,size,color,min(size)*.2 if bevel else 0)
    obj.rotation_euler.x=angle
    return obj


def vent(p,loc,width=.5,count=5):
    x,y,z=loc
    surface(p,'RecessedCoolingBox',loc,(width,.42,.06),'dark',2)
    for i in range(count): surface(p,'CoolingFin',(x,y-.16+i*.32/(count-1),z+.04),(width*.92,.032,.035),'steel',2)


def seat(p,x,y,z):
    cube(p,'BucketCushion',(x,y,z),(.38,.40,.13),'rubber',.04)
    panel(p,'BucketSeatback',(x,y+.18,z+.27),(.4,.13,.53),'shadow',-.12)
    for side in (-1,1): strut(p,'SeatFrame',(x+side*.19,y-.17,z-.1),(x+side*.19,y+.23,z+.42),.028,'steel')


def suspension(p,x,y,z):
    side=1 if x>0 else -1
    strut(p,'Wishbone',(side*.4,y-.16,z+.10),(x,y,z),.035)
    strut(p,'Wishbone',(side*.4,y+.16,z+.10),(x,y,z),.035)
    strut(p,'Damper',(side*.6,y,z+.36),(x,y,z-.03),.045,'amber')
    strut(p,'DamperPiston',(side*.61,y,z+.28),(x,y,z),.023,'cream')


def buggy():
    p=group('buggy')
    hull(p,'SkidPan',[(-1.13,.5,.24,.41,.06),(-.50,.67,.24,.48,.06),(.88,.60,.24,.48,.06)],'steel')
    for x in (-.85,.85):
        for y in (-.84,.84):
            wheel(p,'Wheel_%s_%s'%(x,y),x,y,.43,.43,.27);suspension(p,x,y,.43)
    hull(p,'SlopedNose',[(-1.12,.49,.48,.59,.04),(-.44,.61,.48,.88,.06)],'paint')
    for side in (-1,1):
        x=side*.6
        strut(p,'CageSill',(x,-.50,.57),(x,.68,.57),.045)
        strut(p,'FrontPillar',(x,-.42,.72),(x,-.13,1.39),.045)
        strut(p,'RoofRail',(x,-.13,1.39),(x,.59,1.44),.045)
        strut(p,'RearPillar',(x,.59,1.44),(x,.87,.57),.045)
        strut(p,'DiagonalDoorBar',(x,-.43,.70),(x,.53,1.15),.04)
        panel(p,'SideHalfArmor',(x,.06,.67),(.035,.69,.23),'paint')
        for y in (-.84,.84): panel(p,'CycleFender',(side*.85,y,.88),(.37,.59,.07),'paint')
        cube(p,'Headlight',(side*.41,-1.14,.58),(.18,.055,.12),'cream',.015)
        seat(p,side*.27,.11,.59)
    for y,z in ((-.13,1.39),(.59,1.44)):
        strut(p,'RoofCrossbar',(-.6,y,z),(.6,y,z),.045)
    strut(p,'CrossBrace',(-.6,.59,1.44),(.6,.83,.62),.035)
    strut(p,'CrossBrace',(.6,.59,1.44),(-.6,.83,.62),.035)
    cube(p,'RearEngine',(0,.88,.65),(.69,.52,.32),'dark',.04)
    vent(p,(0,.86,.84),.57)
    for side in (-1,1):
        cyl(p,'Exhaust',(side*.39,.90,.82),.05,.49,'steel',vertices=8)
    strut(p,'FrontBumper',(-.74,-1.18,.40),(.74,-1.18,.40),.07)
    cyl(p,'GunPedestal',(0,.46,1.50),.13,.22,'steel',(0,0,0),10)
    gun=cube(p,'WeaponPitch',(0,.27,1.66),(.22,.37,.17),'shadow',.02)
    parts=[cyl(p,'GunBarrel',(0,-.08,1.66),.055,.62,'steel',vertices=10),cube(p,'AmmoCan',(.22,.3,1.65),(.22,.29,.20),'amber',.02)]
    join_into(gun,parts)
    return p


def raider():
    p=group('raider')
    hull(p,'ArmoredChassis',[(-1.79,1.0,.39,.83,.12),(-.9,1.16,.39,1.1,.14),(1.63,1.1,.39,1.02,.12)],'shadow')
    for side in (-1,1):
        x=side*1.32
        for y in (-1.25,1.13):
            wheel(p,'Wheel_%s_%s'%(x,y),x,y,.55,.55,.31)
            panel(p,'FlaredFender',(x,y,1.14),(.56,.95,.10),'paint')
        strut(p,'RockerTube',(side*1.25,-.68,.57),(side*1.25,.58,.57),.055)
    hull(p,'Cab',[(-1.08,.99,.85,1.30,.10),(-.53,.94,.85,2.01,.10),(.53,.94,.85,2.01,.10)],'paint')
    hull(p,'BeakedHood',[(-1.72,.91,.79,1.05,.08),(-1.04,.99,.79,1.30,.08)],'light')
    for side in (-1,1):
        # Windshield follows the cab rake, with a central armored divider.
        panel(p,'Windshield',(side*.43,-.80,1.64),(.71,.035,.47),'glass',-.66)
        panel(p,'SideWindow',(side*.95,-.05,1.70),(.025,.68,.39),'glass')
        panel(p,'Door',(side*.972,.0,1.18),(.04,.72,.43),'light')
        cube(p,'Handle',(side*1.005,.21,1.37),(.04,.16,.035),'steel')
        strut(p,'MirrorArm',(side*.99,-.70,1.51),(side*1.23,-.65,1.63),.024)
        cube(p,'Mirror',(side*1.25,-.65,1.65),(.06,.16,.22),'shadow',.02)
        panel(p,'RearSideArmor',(side*1.05,1.04,1.27),(.1,1.1,.50),'paint')
        for y in (.72,1.17): cube(p,'AmmoLocker',(side*.70,y,1.13),(.43,.36,.4),'shadow',.025)
        cube(p,'Lamp',(side*.75,-1.76,1.02),(.22,.055,.17),'cream',.02)
    cube(p,'Grille',(0,-1.74,.86),(1.07,.07,.20),'dark')
    for x in (-.42,-.21,0,.21,.42):cube(p,'GrilleGuard',(x,-1.79,.86),(.04,.04,.20),'steel')
    strut(p,'Bullbar',(-1.15,-1.9,.55),(1.15,-1.9,.55),.085)
    cyl(p,'TurretRace',(0,.85,1.51),.57,.13,'steel',(0,0,0),12)
    hull(p,'RearTurret',[(-.06,.56,1.55,1.84,.10),(1.22,.56,1.55,2.0,.10)],'light')
    gun=cube(p,'WeaponPitch',(.35,.17,1.89),(.31,.48,.28),'shadow',.045)
    join_into(gun,[cyl(p,'Cannon',(.35,-.43,1.89),.09,1.08,'steel',vertices=10),cube(p,'MuzzleBrake',(.35,-.98,1.89),(.22,.22,.19),'dark',.025)])
    rocket=cube(p,'RocketHousing',(-.35,.58,2.07),(.46,.73,.35),'steel',.04)
    for x in (-.46,-.25):
        for z in (1.99,2.16):cyl(p,'RocketTube',(x,.17,z),.074,.07,'dark',vertices=10)
    cyl(p,'CommanderHatch',(0,-.03,2.04),.29,.07,'shadow',(0,0,0),12)
    vent(p,(0,-1.33,1.19),.51)
    return p


def track(p,name,x,half_length,radius,width,road_count=4):
    """Continuous capsule-shaped belt with exposed road wheels and grousers."""
    z=radius+.035
    points=[]
    for end,start in ((half_length,-math.pi/2),(-half_length,math.pi/2)):
        for i in range(TRACK_SEGMENTS+1):
            angle=start+i*math.pi/TRACK_SEGMENTS
            points.append((end+math.cos(angle)*radius,z+math.sin(angle)*radius))
    # Extruded closed tread surface, interior is hollow so wheels read clearly.
    vertices=[]
    for xx in (x-width/2,x+width/2):
        for y,zz in points: vertices.append((xx,y,zz))
    n=len(points);faces=[]
    for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    belt=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(belt);belt.parent=p;finish(belt,'rubber')
    parts=[]
    for index in range(road_count):
        y=-half_length+index*2*half_length/(road_count-1)
        # Cheap track wheels use three coaxial cylinders, no hidden roadwheel lug hardware.
        parts.append(cyl(p,'TrackRoadWheel',(x,y,z),radius*.81,width*.91,'shadow',(0,math.pi/2,0),8))
        side=1 if x>0 else -1
        parts.append(disc(p,'TrackHub',(x+side*width*.48,y,z),radius*.34,'steel',(0,side*math.pi/2,0),8))
    for i in range(n):
        a=points[i];b=points[(i+1)%n]
        distance=math.dist(a,b);count=max(1,round(distance/TRACK_SHOE_SPACING))
        for j in range(count):
            fraction=(j+.5)/count;y=a[0]+(b[0]-a[0])*fraction;zz=a[1]+(b[1]-a[1])*fraction
            shoe=surface(p,'TreadShoe',(x,y,zz),(width*1.08,distance/count*.67,.048),'steel',2,-1)
            shoe.rotation_euler.x=math.atan2(b[1]-a[1],b[0]-a[0]);parts.append(shoe)
    join_into(belt,parts);return belt


def crawler():
    p=group('repairCrawler')
    for x in (-1.13,1.13):track(p,'ServiceTrack',x,.90,.39,.52)
    hull(p,'LowerHull',[(-1.40,.88,.48,.79,.10),(-.75,.94,.48,.97,.10),(1.30,.90,.48,.97,.10)],'shadow')
    hull(p,'ServiceCab',[(-1.19,.69,.79,1.14,.08),(-.74,.69,.79,1.66,.08),(.05,.69,.79,1.66,.08)],'paint')
    panel(p,'Windshield',(0,-.965,1.41),(1.06,.035,.40),'glass',-.71)
    for side in (-1,1):
        panel(p,'CabSideGlass',(side*.71,-.42,1.40),(.026,.42,.29),'glass')
        panel(p,'TrackSkirt',(side*1.02,.21,.95),(.2,2.02,.14),'light')
        cube(p,'ServiceLocker',(side*.59,.74,1.23),(.43,.94,.55),'paint',.045)
        for y in (.40,.71,1.02):
            surface(p,'ToolDrawer',(side*.819,y,1.27),(.024,.25,.24),'shadow',0,side)
        cube(p,'Worklamp',(side*.54,-1.15,1.04),(.18,.08,.15),'cream',.02)
    vent(p,(0,.65,1.33),.49)
    cyl(p,'CraneRace',(0,1.00,1.43),.24,.20,'steel',(0,0,0),12)
    # Connected knuckle boom with visible piston and tool instead of a floating rod.
    strut(p,'CraneLower',(0,1.,1.54),(.75,.45,2.14),.12,'amber')
    strut(p,'CraneUpper',(.75,.45,2.14),(1.32,-.37,1.56),.10,'amber')
    strut(p,'LiftCylinder',(.02,.95,1.46),(.69,.46,1.99),.07,'shadow')
    strut(p,'LiftPiston',(.34,.70,1.72),(.79,.42,2.03),.043,'cream')
    cyl(p,'CraneJoint',(.75,.45,2.14),.18,.26,'steel',(0,math.pi/2,0),12)
    for side in (-1,1):strut(p,'Claw',(1.32+side*.10,-.37,1.56),(1.32+side*.17,-.48,1.31),.045,'steel')
    cyl(p,'Beacon',(0,-.25,1.76),.10,.16,'amber',(0,0,0),10)
    return p


def boss(variant='armored'):
    # The shared factory owns the new siege chassis; no legacy duplicate model.
    import importlib.util
    from pathlib import Path
    path=Path(__file__).with_name('leviathan_bodywork.py')
    spec=importlib.util.spec_from_file_location('leviathan_bodywork',path)
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    builder.install(globals())
    return builder.build(variant)


def wreck(name,source,size,original_factories):
    factories=dict(original_factories,buggy=buggy,repairCrawler=crawler)
    p=factories[source]();p.name=name
    children=list(p.children)
    if source=='bike':
        for obj in children:
            if obj.name.startswith('Rider'):bpy.data.objects.remove(obj,do_unlink=True)
        # Tip the bike as one rigid assembly, keeping round wheels and frame tubes.
        from mathutils import Matrix
        transform=Matrix.Rotation(math.radians(67),4,'Y')
        for obj in list(p.children):obj.matrix_world=transform@obj.matrix_world
    else:
        for i,obj in enumerate(children):
            lower=obj.name.lower()
            if any(term in lower for term in ('glass','windshield','lamp','beacon','roofhatch','weaponpitch','ammo')):
                bpy.data.objects.remove(obj,do_unlink=True);continue
            if any(term in lower for term in ('rearbody','minebay')):
                bpy.data.objects.remove(obj,do_unlink=True)
                continue
            if lower.startswith('servicetrack'):
                import bmesh
                bm=bmesh.new();bm.from_mesh(obj.data)
                # A thrown belt: remove a full upper run section from one side.
                if 'ServiceTrack' in obj.name and obj.location.x <= 0:
                    broken=[f for f in bm.faces if .15 < f.calc_center_median().y < .64 and f.calc_center_median().z > .46]
                    bmesh.ops.delete(bm,geom=broken,context='FACES')
                    bm.to_mesh(obj.data)
                bm.free()
            if lower.startswith('wheel_'):
                # Rigid bent axles: intact tyre profile and hub, leaning under real weight.
                obj.rotation_euler.y+=(-.36 if obj.location.x<0 else .25)
                obj.rotation_euler.z+=.10 if obj.location.y<0 else -.17
                if obj.location.x < 0 and obj.location.y < 0:
                    obj.rotation_euler=(0,.12,.37)
                    obj.location.z=.15
                    obj.location.y-=.16
                    obj.location.x-=.12
            elif any(term in lower for term in ('cab','rearbody','workshop','servicecab')):
                # Tear a jagged opening through upper bodywork by removing selected faces.
                import bmesh
                bm=bmesh.new();bm.from_mesh(obj.data)
                bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
                broken=[face for face in bm.faces if face.calc_center_median().z>.05 and face.normal.z>.25]
                bmesh.ops.delete(bm,geom=broken,context='FACES')
                for v in bm.verts:
                    if v.co.z>.05:v.co.x+=.17*math.sin(v.index*2.1);v.co.z-=.22*abs(math.sin(v.index))
                bm.to_mesh(obj.data);bm.free()
                obj.rotation_euler.y=.13;obj.rotation_euler.x=-.10
            elif any(term in lower for term in ('hood','armorednose','slopednose')):
                obj.rotation_euler.x=-.38;obj.rotation_euler.y=.27
                obj.location.x+=.17;obj.location.z+=.13
            elif any(term in lower for term in ('jammerhead','jammerscan','antenna')):
                obj.rotation_euler.y+=.67;obj.location.x-=.22;obj.location.z-=.30
            elif any(term in lower for term in ('pillar','roofrail','crossbrace','craneupper','cranelower','repairarm')):
                obj.rotation_euler.y+=.38;obj.location.z-=.15
            if obj.type=='MESH':
                # Select scorched facets, retaining surviving paint as provenance.
                uv=obj.data.uv_layers.active
                if uv:
                    for face in obj.data.polygons:
                        if (face.index+i)%4 != 0:
                            for loop in face.loop_indices:uv.data[loop].uv=(.375,.625) # dark cell
        if source in ('jammerTruck','minelayer'):
            # The cargo shell has torn off; two slumped panels and exposed crossmembers remain.
            for side in (-1,1):
                plate=panel(p,'CollapsedCargoSide',(side*.69,.83,.80),(.05,1.38,.49),'shadow')
                plate.rotation_euler.y=side*.52
            for y in (.25,.67,1.13):strut(p,'CargoCrossmember',(-.69,y,.73),(.66,y,.62),.04,'steel')
        if source == 'repairCrawler':
            for i in range(4):
                shoe=panel(p,'ThrownTrackShoe',(-1.17,.26+i*.14,.15),(.55,.12,.05),'steel')
                shoe.rotation_euler.z=i*.13
        # Buckled steel strips make the destroyed silhouette visibly asymmetric.
        for side in (-1,1):
            y=.25 if side<0 else -.65
            bent=panel(p,'PeeledBodyPanel',(side*size[0]*.31,y,.74),(.41,.58,.045),'paint')
            bent.rotation_euler=(side*.51,side*.68,.23)
            strut(p,'BrokenRoofRail',(side*.48,-.45,.91),(side*.59,.27,1.13),.032,'steel')
        # Exposed engine, bent torn plating and loose frame rails fill the broken shell.
        cube(p,'BurntEngine',(0,-.12,.63),(.66,.61,.40),'dark',.05)
        for z in (.48,.57,.66,.75):cube(p,'ExposedEngineFin',(0,-.15,z),(.74,.58,.027),'steel')
        for side in (-1,1):
            obj=panel(p,'TornArmor',(side*size[0]*.32,.56,.46),(.48,.73,.065),'shadow');obj.rotation_euler=(.18,side*.54,side*.22)
            strut(p,'ExposedFrame',(side*.42,-.82,.30),(side*.46,.9,.38),.045,'steel')
    return p


def utility_truck(name, feature):
    """Pickup-family utility cab with equipment exposed on a proper load bed."""
    p=group(name)
    hull(p,'Frame',[(-1.8,.72,.32,.52,.06),(1.8,.72,.32,.52,.06)],'shadow')
    for side in (-1,1):
        for y in (-1.17,1.18):
            wheel(p,'Wheel_%s_%s'%(side,y),side*.92,y,.48,.48,.31)
            panel(p,'FenderTop',(side*.90,y,1.0),(.44,.75,.08),'paint')
            for end in (-1,1):
                panel(p,'FenderLip',(side*.9,y+end*.37,.88),(.44,.10,.26),'shadow',end*.3)
        panel(p,'Step',(side*.88,-.05,.49),(.28,.69,.09),'steel')
        panel(p,'Door',(side*.738,-.34,.94),(.04,.68,.47),'paint')
        panel(p,'SideWindow',(side*.735,-.30,1.45),(.032,.53,.33),'glass')
        cube(p,'DoorHandle',(side*.773,-.12,1.19),(.05,.16,.035),'cream')
        strut(p,'MirrorArm',(side*.74,-.66,1.28),(side*.98,-.65,1.45),.025)
        cube(p,'Mirror',(side*1.0,-.65,1.46),(.07,.14,.22),'shadow',.02)
        cube(p,'Lamp',(side*.55,-1.80,.85),(.22,.06,.16),'cream',.018)
        panel(p,'BedSide',(side*.76,.97,.97),(.10,1.56,.43),'paint')
        panel(p,'BedRail',(side*.78,.97,1.22),(.15,1.62,.06),'light')
        cube(p,'TailLamp',(side*.63,1.79,.76),(.15,.05,.16),'red')
    hull(p,'PickupCab',[(-.94,.72,.56,1.13,.06),(-.56,.72,.56,1.75,.06),(.15,.72,.56,1.75,.06)],'paint')
    hull(p,'Hood',[(-1.77,.68,.64,.91,.06),(-.92,.72,.64,1.14,.06)],'light')
    for side in (-1,1):panel(p,'Windshield',(side*.34,-.759,1.46),(.58,.035,.48),'glass',-.55)
    panel(p,'Roof',(0,-.18,1.78),(1.51,.84,.09),'light')
    cube(p,'Grille',(0,-1.795,.67),(.83,.07,.21),'dark')
    for x in (-.32,-.16,0,.16,.32):cube(p,'GrilleSlat',(x,-1.84,.67),(.045,.04,.22),'steel')
    cube(p,'Bumper',(0,-1.89,.48),(1.89,.18,.18),'shadow',.02)
    for side in (-1,1):strut(p,'BullbarUpright',(side*.64,-1.96,.45),(side*.64,-1.96,1.01),.043)
    strut(p,'BullbarTop',(-.79,-1.96,1.01),(.79,-1.96,1.01),.043)
    cube(p,'BedFloor',(0,1.0,.68),(1.46,1.69,.12),'shadow')
    vent(p,(0,-1.23,1.08),.46)
    if feature=='jammer':
        cube(p,'Transceiver',(0,.80,1.04),(.98,.84,.59),'shadow',.04)
        for side in (-1,1):
            for y in (.51,.65,.79,.93,1.07):surface(p,'HeatSink',(side*.52,y,1.05),(.08,.035,.48),'steel',0,side)
        cyl(p,'Mast',(0,.80,1.71),.075,.88,'steel',(0,0,0),10)
        head=cube(p,'JammerHead',(0,.80,2.16),(.21,.21,.15),'steel')
        pieces=[]
        for side in (-1,1):
            pieces.append(panel(p,'AntennaPanel',(side*.48,.80,2.13),(.39,.12,.59),'cream'))
            pieces.append(strut(p,'AntennaBeam',(0,.80,2.15),(side*.51,.80,2.15),.035))
        join_into(head,pieces)
        cyl(p,'JammerScan',(0,.80,1.68),.49,.06,'amber',(0,0,0),12)
        strut(p,'Whip',(-.59,1.52,1.24),(-.59,1.52,2.33),.018,'steel')
    else:
        for side in (-1,1):
            panel(p,'ConveyorRail',(side*.39,1.16,1.19),(.08,1.33,.1),'steel',-.22)
            for y in (.56,.91,1.26):
                cyl(p,'Mine',(side*.32,y,1.13),.21,.13,'shadow',(0,0,0),10)
                cyl(p,'MineFuse',(side*.32,y,1.23),.06,.06,'amber',(0,0,0),8)
        panel(p,'DeploymentChute',(0,1.75,.89),(.91,.63,.08),'steel',-.48)
        gun=cube(p,'WeaponPitch',(0,-.20,1.94),(.23,.30,.19),'shadow',.02)
        join_into(gun,[cyl(p,'Barrel',(0,-.60,1.94),.045,.63,'steel',vertices=10)])
    return p


def variant_details(p, variant):
    """Shared pickup construction language; role silhouette stays recognizable."""
    name=p.name
    if name == 'boss': return p
    # Purposeful hardware on all six chassis; merged into their static body.
    sizes={'buggy':(.60,-1.12,.64),'raider':(.96,-1.72,1.05),
           'jammerTruck':(.70,-1.78,.89),'minelayer':(.70,-1.78,.89),
           'repairCrawler':(.70,-1.19,1.05),'boss':(1.61,-2.31,1.40)}
    half,front,z=sizes[name]
    for side in (-1,1):
        cube(p,'RecoveryMount',(side*half*.62,front-.07,z-.32),(.17,.10,.17),'amber',.025)
        cube(p,'RecoveryInset',(side*half*.62,front-.13,z-.32),(.075,.015,.07),'dark')
    if name=='buggy':
        panel(p,'RoofVisor',(0,-.02,1.47),(1.30,.39,.07),'light')
        cube(p,'NoseGrille',(0,-1.14,.54),(.51,.04,.16),'dark')
        for x in (-.17,0,.17):cube(p,'GrilleRib',(x,-1.17,.54),(.028,.04,.15),'steel')
        # Distinct spare wheel, utility basket and lamp bar visible from game camera.
        cyl(p,'SpareTyre',(0,.84,1.14),.31,.19,'rubber',(0,0,0),16)
        cyl(p,'SpareHub',(0,.84,1.25),.16,.025,'steel',(0,0,0),10)
    if name=='raider':
        for side in (-1,1):
            strut(p,'RoofRack',(side*.82,-.40,2.11),(side*.82,.44,2.11),.035)
            cube(p,'Stowage',(side*.68,1.35,1.65),(.38,.33,.32),'shadow',.03)
        for x in (-.58,-.29,0,.29,.58):cube(p,'RoofLamp',(x,-.48,2.10),(.16,.12,.11),'cream',.012)
    if name=='repairCrawler':
        cube(p,'FrontRadiator',(0,-1.21,1.03),(.61,.06,.22),'dark')
        for x in (-.24,-.12,0,.12,.24):cube(p,'RadiatorFin',(x,-1.25,1.03),(.025,.05,.22),'steel')
        for side in (-1,1):
            cube(p,'ServiceStripe',(side*.825,.75,1.48),(.024,.72,.06),'cream')
            cyl(p,'AirTank',(side*.67,1.21,1.65),.14,.51,'amber',vertices=10)
    if variant=='armored':
        if name=='buggy':
            panel(p,'HardRoof',(0,.31,1.50),(1.33,.75,.10),'paint')
            for side in (-1,1):
                panel(p,'BallisticDoor',(side*.625,.11,.91),(.07,.85,.45),'paint')
                panel(p,'WindowGuard',(side*.65,.16,1.25),(.035,.62,.11),'shadow')
        else:
            length={'raider':1.12,'jammerTruck':1.46,'minelayer':1.46,'repairCrawler':1.30,'boss':2.8}[name]
            for side in (-1,1):
                panel(p,'AppliqueArmor',(side*(half+.14),.20+length*.5,z+.27),(.15,length-.07,.43),'light')
            panel(p,'HoodArmor',(0,front+.34,z+.08),(half*1.5,.47,.09),'paint',-.10)
    return p
