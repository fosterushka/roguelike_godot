"""Purpose-built vehicle silhouettes and rigid damaged variants.

All geometry is authored before palette batching. Existing wheels, weapon and
Leviathan component names remain the runtime animation/collision contract.
"""
import math
import bpy
from mathutils import Vector


def install(api):
    globals().update({key: api[key] for key in ('group','cube','cyl','strut','wheel','finish','join_into')})


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


def panel(p,name,loc,size,color='paint',angle=0):
    obj=cube(p,name,loc,size,color,min(size)*.2);obj.rotation_euler.x=angle;return obj


def vent(p,loc,width=.5,count=5):
    x,y,z=loc
    cube(p,'RecessedCoolingBox',loc,(width,.42,.06),'dark',.018)
    for i in range(count): cube(p,'CoolingFin',(x,y-.16+i*.32/(count-1),z+.04),(width*.92,.032,.035),'steel')


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


def track(p,name,x,half_length,radius,width,road_count=5):
    """Continuous capsule-shaped belt with exposed road wheels and grousers."""
    z=radius+.035
    points=[]
    for end,start in ((half_length,-math.pi/2),(-half_length,math.pi/2)):
        for i in range(9):
            angle=start+i*math.pi/8
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
        parts.append(cyl(p,'TrackRoadWheel',(x,y,z),radius*.81,width*.91,'shadow',(0,math.pi/2,0),12))
        for side in (-1,1):parts.append(cyl(p,'TrackHub',(x+side*width*.48,y,z),radius*.34,.035,'steel',(0,math.pi/2,0),10))
    for i in range(n):
        a=points[i];b=points[(i+1)%n]
        distance=math.dist(a,b);count=max(1,round(distance/.17))
        for j in range(count):
            fraction=(j+.5)/count;y=a[0]+(b[0]-a[0])*fraction;zz=a[1]+(b[1]-a[1])*fraction
            shoe=cube(p,'TreadShoe',(x,y,zz),(width*1.08,distance/count*.67,.048),'steel')
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
            cube(p,'ToolDrawer',(side*.819,y,1.27),(.024,.25,.24),'shadow',.01)
            cube(p,'DrawerHandle',(side*.84,y,1.28),(.035,.12,.025),'cream')
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


def boss():
    p=group('boss')
    for side in (-1,1):track(p,'Component_%sDrive'%('Left' if side<0 else 'Right'),side*2.23,1.32,.68,1.0,6)
    hull(p,'ArmoredCitadel',[(-2.17,1.53,.80,1.55,.18),(-1.18,1.77,.80,2.29,.20),(1.68,1.68,.80,2.40,.20),(2.09,1.42,.80,1.74,.16)],'paint')
    hull(p,'SlopedGlacis',[(-2.32,1.65,1.03,1.32,.10),(-1.38,1.83,1.12,2.01,.14)],'light')
    for side in (-1,1):
        for i in range(4):
            panel(p,'SpacedSideArmor',(side*1.87,-1.36+i*.86,1.80),(.18,.70,.60),'light')
        for y in (-1.84,1.67):cube(p,'RunningLamp',(side*1.44,y,1.66),(.31,.09,.14),'cream' if y<0 else 'red',.015)
        vent(p,(side*1.07,1.42,2.36),.55)
    # Core and pods are authored at existing gameplay anchors (after 2.1x scale).
    core=cube(p,'Component_Core',(0,-.126,2.797),(1.12,1.08,1.08),'shadow',.12)
    parts=[]
    for z in (2.45,2.70,2.95,3.20):parts.append(cyl(p,'ReactorRing',(0,-.126,z),.54,.10,'steel',(0,0,0),12))
    for side in (-1,1):parts.append(panel(p,'ReactorGlow',(side*.571,-.126,2.81),(.028,.60,.59),'amber'))
    join_into(core,parts)
    hull(p,'CommandTower',[(.49,.78,2.17,3.70,.12),(1.35,.78,2.17,3.70,.12)],'shadow')
    missile=cube(p,'Component_MissilePod',(0,.754,3.96),(1.63,1.23,.56),'paint',.09)
    parts=[]
    for x in (-.57,-.19,.19,.57):
        for z in (3.82,4.09):parts.append(cyl(p,'MissileCell',(x,.108,z),.11,.10,'dark',vertices=10))
    parts.append(panel(p,'MissileRoof',(0,.75,4.28),(1.74,1.30,.09),'light'))
    join_into(missile,parts)
    gun=cube(p,'Component_GunPod',(.943,-.817,3.457),(.98,.97,.61),'light',.10)
    parts=[cyl(p,'GunTrunnion',(.943,-.38,2.9),.19,.91,'steel',(0,0,0),12)]
    for x in (.76,1.12):
        parts.append(cyl(p,'GatlingBarrel',(x,-1.66,3.47),.09,1.02,'steel',vertices=10))
        parts.append(cube(p,'GatlingMuzzle',(x,-2.22,3.47),(.19,.18,.18),'dark',.02))
    join_into(gun,parts)
    cyl(p,'Mantlet',(0,-2.06,1.93),.31,.38,'shadow',vertices=12)
    cyl(p,'SiegeCannon',(0,-2.66,1.93),.13,1.14,'steel',vertices=12)
    cube(p,'SiegeMuzzle',(0,-3.26,1.93),(.36,.29,.29),'shadow',.04)
    return p


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
