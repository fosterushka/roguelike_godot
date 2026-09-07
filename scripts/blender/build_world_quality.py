"""Authored field dressing, wildlife and machinery kit. Same atlas as the pickup.
Coordinates in modelling functions are Godot Y-up; export conversion is centralized.
"""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/world_quality'
GAME = ROOT / 'assets/environment/world_quality.glb'
sys.path.insert(0, str(Path(__file__).parent))
import build_player
from pickup_geometry import PALETTE

PARTS = []
MATERIAL = None
BEVEL = .025
SIDES = 12
# These pooled meshes are stretched by existing world transforms. Retain the
# source local bounds so new seams/hardware cannot move fences or collisions.
POOL_SOURCE_INDEX = {'barrelInstances':16,'crateInstances':17,'fencePosts':18,'fenceRails':19,
    'ironStructure':20,'metalStructure':21,'woodStructure':22,'redStructure':23,
    'tankInstances':24,'earthStructure':25,'ruinStructure':26,'scarStructure':27,
    'cliffFaces':33,'cliffStrata':34}



def point(p):
    return Vector((p[0], -p[2], p[1]))


def finish(obj, color):
    obj.data.materials.clear()
    obj.data.materials.append(MATERIAL)
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='PaletteUV')
    cell = list(PALETTE).index(color)
    for loop in uv.data:
        loop.uv = ((cell % 4 + .5) / 4, (cell // 4 + .5) / 4)
    PARTS.append(obj)
    return obj


def box(p, size, color='paint', bevel=BEVEL):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(p))
    obj = bpy.context.object
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Panel edges', 'BEVEL')
        mod.width = min(bevel, min(size) * .2)
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, color)


def tube(p, radius, length, color='steel', axis=(0,1,0), sides=SIDES):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=length, location=point(p))
    obj = bpy.context.object
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(point(axis).normalized())
    return finish(obj, color)


def beam(a, b, radius=.035, color='steel'):
    a, b = Vector(a), Vector(b)
    return tube((a+b)*.5, radius, (b-a).length, color, b-a, 8)


def ellipsoid(p, size, color, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=point(p))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, color)


def bolts(p, width, height):
    for x in [-width/2, width/2]:
        for y in [-height/2, height/2]:
            tube((p[0]+x,p[1]+y,p[2]), .032,.028,'steel',(0,0,1),6)


def panel(p, size):
    box(p,size,'paint_shadow')
    bolts((p[0],p[1],p[2]+size[2]/2+.014),size[0]*.8,size[1]*.8)


def ladder(x, z, height):
    for side in [-1,1]: beam((x+side*.32,.15,z),(x+side*.32,height,z),.035)
    for i in range(int(height/.3)):
        beam((x-.32,.2+i*.3,z),(x+.32,.2+i*.3,z),.028,'accent')


def crate(p=(0,0,0), size=(.9,.8,.85)):
    x,y,z=p; w,h,d=size
    box((x,y+h/2,z),(w,h,d),'bed')
    for side in [-1,1]:
        for stripe in [-.32,.32]:
            box((x+stripe*w,y+h/2,z+side*d*.51),(.065,h,.045),'steel')
        for level in [.1,.9]: box((x,y+level*h,z+side*d*.52),(w,.07,.055),'paint_light')
        box((x+side*w*.51,y+h*.56,z),(.06,.06,d*.45),'trim')
    for stripe in [-.32,.32]: box((x+stripe*w,y+h+.025,z),(.065,.05,d),'steel')
    box((x,y+h*.55,z+d*.53),(.24,.14,.018),'accent')
    bolts((x,y+h*.55,z+d*.55),w*.8,h*.6)


def sheep():
    ellipsoid((0,.72,0),(.43,.39,.70),'white')
    for row in range(5):
        z=-.45+row*.22
        for side in [-1,1]: ellipsoid((side*.28,.79,z),(.19,.21,.20),'white',1)
    ellipsoid((0,.82,.66),(.20,.26,.32),'trim')
    ellipsoid((0,.72,.91),(.17,.12,.14),'dark')
    for side in [-1,1]:
        ear=ellipsoid((side*.25,.99,.64),(.19,.07,.10),'paint_shadow',1)
        ear.rotation_euler.y=side*.3
        ellipsoid((side*.175,.90,.77),(.028,.035,.028),'lamp',1)
        ellipsoid((side*.196,.90,.785),(.012,.02,.013),'dark',1)
        for z in [-.38,.39]:
            beam((side*.27,.6,z),(side*.29,.13,z+.03),.075,'trim')
            box((side*.29,.085,z+.06),(.15,.15,.20),'dark')
    ellipsoid((0,.76,-.7),(.12,.18,.12),'white',1)


def house():
    # Roof geometry is expressed in Godot coordinates before point() conversion.
    # Using Blender Euler Y here previously sloped the roof along the wrong axis.
    roof_half_width, roof_half_depth = 1.78, 1.62
    eave_height, ridge_height, roof_thickness = 1.91, 2.56, .10

    def solid(name, vertices, faces, color):
        import bmesh
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([point(p) for p in vertices], [], faces)
        mesh.update()
        bm = bmesh.new(); bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh); bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return finish(obj, color)

    box((0,.10,0),(3.2,.2,3.0),'steel')
    box((0,.98,0),(3,1.8,2.8),'paint_shadow',.04)
    for side in [-1,1]:
        for i in range(8): box((side*1.515,.98,-1.23+i*.35),(.045,1.72,.065),'paint')
        # Closed sloping sheets have outward normals on both faces and solid edges.
        vertices = [(0,ridge_height,z) for z in [-roof_half_depth,roof_half_depth]]
        vertices += [(side*roof_half_width,eave_height,z) for z in [-roof_half_depth,roof_half_depth]]
        vertices += [(x,y-roof_thickness,z) for x,y,z in vertices]
        solid('Pitched roof sheet', vertices,
              [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],'steel')
        for i in range(9):
            z=-1.54+i*.385
            beam((0,ridge_height+.023,z),(side*roof_half_width,eave_height+.023,z),.022,'paint_light')
        for z in [-roof_half_depth,roof_half_depth]:
            beam((0,ridge_height+.025,z),(side*roof_half_width,eave_height+.025,z),.047,'accent')
        beam((side*roof_half_width,eave_height-.025,-roof_half_depth),
             (side*roof_half_width,eave_height-.025,roof_half_depth),.055,'trim')
        # Triangular gable closes the cavity under the ridge, front and rear.
        z=side*1.405
        solid('Gable wall', [(-1.5,1.87,z),(1.5,1.87,z),(0,2.44,z),
                            (-1.5,1.87,z-side*.08),(1.5,1.87,z-side*.08),(0,2.44,z-side*.08)],
              [(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],'paint_shadow')
        for x in [-1.5,1.5]: box((x,1.03,side*1.42),(.09,1.68,.08),'accent')
    beam((0,ridge_height+.018,-roof_half_depth-.04),(0,ridge_height+.018,roof_half_depth+.04),.065,'paint_light')
    for x in [-1.55,1.55]:
        beam((x,1.88,-1.48),(x,.30,-1.48),.04,'trim')
        beam((x,.30,-1.48),(x,.20,-1.68),.04,'trim')
    box((0,.64,1.435),(.80,1.25,.08),'bed')
    for x in [-.43,.43]: box((x,.68,1.51),(.08,1.4,.10),'accent')
    box((0,1.39,1.51),(.94,.09,.10),'accent')
    box((.26,.66,1.51),(.035,.13,.04),'steel')
    for x in [-.98,.98]:
        box((x,1.2,1.43),(.60,.54,.06),'dark')
        box((x,1.2,1.47),(.48,.43,.035),'glass_light')
        box((x,1.2,1.50),(.035,.48,.03),'steel')
        box((x,.91,1.50),(.7,.07,.17),'accent')
    tube((-.94,2.37,-.85),.1,1.3,'trim')
    tube((-.94,3.04,-.85),.15,.08,'steel')
    box((-.94,2.20,-.85),(.38,.035,.38),'paint_shadow')
    panel((1.55,.75,-.55),(.09,.60,.6))
    for i in range(3): box((0,.04+i*.06,1.9-i*.16),(1.2,.08,.3),'steel')


def well():
    for level in range(4):
        for i in range(12):
            a=math.tau*(i+.5*(level%2))/12
            obj=box((math.sin(a)*.78,.17+level*.25,math.cos(a)*.78),(.40,.23,.28),'steel',.025)
            obj.rotation_euler.z=-a
    for side in [-1,1]:
        box((side*.86,1.2,0),(.14,2.4,.16),'bed')
        beam((side*.86,1.7,0),(side*.45,2.3,0),.055,'accent')
    tube((0,1.86,0),.13,1.95,'bed',(1,0,0))
    for i in range(12): tube((-.30+i*.05,1.86,0),.15,.025,'accent',(1,0,0))
    beam((0,1.86,.15),(0,.45,.15),.018,'accent')
    for side in [-1,1]:
        roof=box((0,2.40,side*.38),(2.3,.10,.9),'paint')
        roof.rotation_euler.x=side*.3
    tube((1.02,1.65,0),.06,.5,'steel')
    tube((1.15,1.42,0),.055,.25,'bed',(1,0,0))


def stall():
    for x in [-1.08,1.08]:
        for z in [-.54,.54]: box((x,1.08,z),(.10,2.16,.10),'bed')
    for i in range(7): box((-1.05+i*.35,.84,0),(.32,.12,1.4),'paint_light')
    for x in [-1.1,1.1]: beam((x,.2,-.54),(x,.78,.54),.04,'accent')
    for i in range(8):
        obj=box((-1.27+i*.36,2.2,0),(.36,.07,1.7),'white' if i%2 else 'paint')
        obj.rotation_euler.x=.07
        box((-1.27+i*.36,2.06,.84),(.36,.28,.04),'white' if i%2 else 'paint')
    for x in [-.7,0,.7]: crate((x,.90,0),(.55,.35,.65))
    box((0,1.4,-.66),(1.4,.35,.04),'bed')


def pole():
    tube((0,1.8,0),.11,3.6,'bed')
    box((0,2.92,0),(1.6,.12,.14),'steel')
    for x in [-.6,0,.6]:
        tube((x,3.08,0),.065,.25,'white')
        for y in [3.0,3.08,3.16]: tube((x,y,0),.095,.035,'white')
    panel((.15,1.6,.1),(.38,.55,.20))
    for y in [.9,1.85]: box((0,y,.10),(.22,.05,.10),'steel')
    beam((0,2.65,0),(.5,2.65,.5),.05)
    box((.50,2.62,.53),(.3,.1,.32),'trim')
    box((.50,2.56,.53),(.23,.025,.25),'lamp')


def wreck():
    # Burnt civilian pickup shell: a bent frame, open cab and exposed drivetrain.
    for side in [-1,1]:
        beam((side*.56,.27,-1.30),(side*.56,.32,1.20),.075,'trim')
    for z in [-1.0,-.55,.10,.85]:
        beam((-.62,.31,z),(.62,.31,z),.055,'steel')
    box((0,.39,-.48),(1.14,.055,1.3),'bed')
    for i in range(8): box((-.49+i*.14,.425,-.68),(.028,.025,1.0),'steel',.002)
    for side in [-1,1]:
        box((side*.65,.58,-.84),(.10,.39,1.00),'paint_shadow',.012)
        box((side*.67,.84,-.84),(.07,.04,1.05),'steel',.009)
        beam((side*.60,.76,.38),(side*.50,1.16,.08),.055,'trim')
        beam((side*.50,1.16,.08),(side*.56,.97,-.51),.05,'steel')
        beam((side*.56,.97,-.51),(side*.63,.49,-.63),.05,'trim')
    beam((-.50,1.16,.08),(.50,1.16,.08),.045,'steel')
    beam((-.56,.97,-.51),(.56,.97,-.51),.045,'steel')
    roof=box((.03,1.065,-.23),(1.02,.055,.58),'paint_shadow',.014)
    roof.rotation_euler.x=.27; roof.rotation_euler.y=.16
    for i in range(3):
        seam=box((-.36+i*.34,1.105,-.22),(.023,.018,.49),'steel',.003)
        seam.rotation_euler.x=.27
    # Only one attached door; the opposite twisted panel lies beside the shell.
    door=box((-.67,.64,-.05),(.07,.41,.64),'paint',.016)
    door.rotation_euler.z=-.19
    box((-.72,.74,-.17),(.025,.045,.16),'accent',.004)
    loose=box((.96,.19,.06),(.60,.055,.74),'paint_shadow',.012)
    loose.rotation_euler.y=-.16;loose.rotation_euler.z=.27
    beam((.65,.25,.45),(1.19,.19,.45),.028,'steel')
    for x in [-.28,.28]:
        box((x,.52,-.21),(.36,.14,.31),'dark',.025)
        seat=box((x,.68,-.40),(.34,.39,.10),'trim',.018);seat.rotation_euler.x=.18
    box((0,.66,.38),(1.10,.13,.16),'trim')
    tube((-.28,.83,.23),.15,.035,'dark',(0,.7,-.7),12)
    beam((-.28,.76,.28),(-.28,.63,.38),.035,'steel')
    # Broken front leaves a readable engine block, belts, intake and radiator.
    box((0,.51,.83),(.57,.32,.58),'trim',.035)
    for x in [-.17,.17]:
        box((x,.70,.84),(.19,.095,.57),'steel',.015)
        for z in [.64,.82,1.0]: tube((x,.76,z),.026,.025,'accent',sides=6)
    for x in [-.27,.27]:
        for z in [.65,.84,1.03]: beam((x,.63,z),(x*1.36,.46,z+.08),.035,'bed')
    tube((0,.63,.80),.16,.09,'paint_shadow')
    tube((0,.69,.80),.11,.025,'dark')
    box((0,.48,1.19),(.92,.38,.07),'steel',.012)
    for i in range(10): box((-.40+i*.09,.48,1.235),(.028,.30,.015),'dark',.001)
    for side in [-1,1]:
        fender=box((side*.61,.64,.91),(.23,.065,.65),'paint',.025)
        fender.rotation_euler.y=side*.16;fender.rotation_euler.x=side*.12
        tube((side*.53,.50,1.29),.115,.025,'dark',(0,0,1))
        beam((side*.70,.25,1.30),(side*.40,.24,1.36),.055,'steel')
    hood=box((.12,.87,1.03),(.81,.05,.45),'paint_shadow',.018)
    hood.rotation_euler.x=-.43;hood.rotation_euler.y=.19
    for z in [-.90,.87]:
        beam((-.77,.25,z),(.77,.25,z),.055,'trim')
        tube((0,.25,z),.12,.22,'steel',(1,0,0))
        for side in [-1,1]:
            # One front wheel has torn away, exposing its hub and brake disc.
            if side==1 and z>0:
                tube((side*.80,.27,z),.15,.06,'steel',(1,0,0))
                continue
            tube((side*.77,.25,z),.255,.19,'rubber',(1,0,0),16)
            tube((side*.88,.25,z),.17,.028,'steel',(1,0,0),12)
            tube((side*.90,.25,z),.105,.035,'trim',(1,0,0),12)
            for bolt in range(5):
                a=bolt*math.tau/5
                tube((side*.927,.25+math.sin(a)*.075,z+math.cos(a)*.075),.018,.015,'accent',(1,0,0),6)
    tube((1.1,.13,.99),.26,.17,'rubber',(0,1,0),16)
    tube((1.1,.23,.99),.16,.025,'steel',(0,1,0),12)
    for x in [-.5,.5]: box((x,.48,-1.37),(.22,.11,.035),'red',.006)
    beam((-.65,.24,-1.46),(.58,.28,-1.39),.065,'steel')


def barrel():
    tube((0,0,0),.46,.95,'paint_shadow',sides=16)
    for y in [-.46,-.3,.3,.46]: tube((0,y,0),.478,.045,'steel',sides=16)
    tube((0,.49,0),.425,.025,'paint',sides=16)
    tube((.23,.512,.15),.065,.025,'accent')
    box((0,0,.465),(.29,.25,.025),'amber')


def tank():
    tube((0,0,0),.5,1,'steel',sides=20)
    for y in [-.46,.46]: tube((0,y,0),.52,.06,'paint_shadow',sides=20)
    tube((0,.52,0),.16,.06,'trim')
    for i in range(8):
        a=i*math.tau/8
        tube((math.sin(a)*.13,.56,math.cos(a)*.13),.015,.02,'accent',sides=6)
    tube((.47,0,0),.07,.16,'trim',(1,0,0))


def machinery(kind):
    if kind in ['watchtower','water_tower']:
        h=4.9 if kind=='watchtower' else 6.7
        ladder(.85,1.85,h)
        for y in [1.3,2.7,4.1]:
            for side in [-1,1]: beam((side*1.15,y-1.1,-1.15),(side*1.15,y+1.1,1.15),.045)
        if kind=='watchtower':
            crate((-.8,5.05,-.7),(.8,.55,.7))
            box((.9,5.65,-.8),(.6,.75,.5),'bed')
            tube((.9,6.5,-.8),.025,1.2,'steel')
        else:
            beam((1.5,.15,0),(1.5,5.5,0),.10)
            tube((1.52,1.1,.14),.24,.04,'red',(0,0,1))
    elif kind=='factory':
        for x in [-4,-2,2,4]:
            box((x,1.5,3.55),(.12,2.9,.15),'paint_light')
            bolts((x,1.5,3.64),.02,2.5)
        for x in [-3.5,3.5]:
            panel((x,1.1,3.64),(1.2,1.6,.1))
            for y in [.5,.7,.9,1.1,1.3]: box((x,y,3.71),(.9,.045,.04),'steel')
        ladder(-4.6,3.8,3.5)
        for x in [-3.6,3.6]:
            for y in [3.7,5,6.6]: tube((x,y,-2.4),.64,.12,'accent')
    elif kind=='crane':
        for x in [-2.7,2.7]:
            for i in range(5):
                beam((x-.25,.3+i*1.2,.3),(x+.25,1.5+i*1.2,.3),.055,'accent')
        for z in [-.28,.28]: beam((1.1,6.9,z),(1.1,3.8,z),.025,'trim')
        tube((1.1,3.6,0),.24,.30,'steel',(0,0,1))
        box((1.1,3.7,0),(.65,.3,.55),'amber')
        beam((1.1,3.6,0),(1.1,3.2,.12),.08)
    elif kind=='refinery':
        for x in [-4.4,4.4]:
            for z in [-2,0,2]:
                tube((x,1.15,z),.26,.12,'accent',(0,0,1))
                for a in range(6):
                    angle=a*math.tau/6
                    tube((x+math.sin(angle)*.20,1.15+math.cos(angle)*.20,z+.08),.025,.045,'steel',(0,0,1),6)
            beam((x,.65,0),(x,2,0),.12)
            tube((x,2,.18),.32,.07,'red',(0,0,1))
        ladder(.6,-4,6.8)
    elif kind=='pumpjack':
        tube((-1.5,1.1,.8),.5,.35,'paint_shadow',(0,0,1))
        tube((-1.5,1.1,1),.23,.06,'steel',(0,0,1))
        beam((-1.5,1.1,1),(0,2.3,1),.045,'rubber')
        for x in [-2.3,-.7]: bolts((x,.8,.62),.06,.6)
        for i in range(7): box((-2.15+i*.22,1.39,0),(.10,.1,1.1),'steel')
    elif kind=='satellite':
        panel((0,1,4.8),(1.2,1.3,.15))
        for x in [-.4,0,.4]: tube((x,1.2,4.9),.05,.025,'lamp',(0,0,1))
        for i in range(5): box((0,.55+i*.1,4.9),(1,.035,.03),'steel')


def dish():
    tube((0,1.5,0),.17,3,'paint_shadow')
    box((0,.18,0),(1,.35,1),'steel')
    # Concave paraboloid, with a real rim and feed support, facing +Z.
    verts=[]; faces=[]; rings=5; sides=24
    for r in range(rings):
        radius=.05+r*.4
        for i in range(sides):
            a=i*math.tau/sides
            verts.append(point((math.cos(a)*radius,3.4+math.sin(a)*radius,radius*radius*.17)))
    for r in range(rings-1):
        for i in range(sides):
            j=(i+1)%sides
            faces.append((r*sides+i,r*sides+j,(r+1)*sides+j,(r+1)*sides+i))
    mesh=bpy.data.meshes.new('dish');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('dish',mesh);bpy.context.collection.objects.link(obj)
    finish(obj,'paint_light')
    for i in range(12):
        a=i*math.tau/12;b=(i+1)*math.tau/12
        beam((math.cos(a)*1.65,3.4+math.sin(a)*1.65,.46),(math.cos(b)*1.65,3.4+math.sin(b)*1.65,.46),.04,'steel')
    for a in [0,math.tau/3,math.tau*2/3]: beam((math.cos(a)*1.6,3.4+math.sin(a)*1.6,.44),(0,3.4,1.05),.025,'steel')
    tube((0,3.4,1.08),.13,.2,'accent',(0,0,1))


def dead_tree():
    joints=[(0,0,0),(.05,1.5,0),(-.08,3,.09),(.16,4.5,.02),(.31,5.5,-.1)]
    for i in range(len(joints)-1): beam(joints[i],joints[i+1],.22-i*.042,'bed')
    for i in range(7):
        a=i*2.4; y=1.5+i*.43
        start=(0,y,0); end=(math.sin(a)*(1.25-i*.08),y+.7,math.cos(a)*(1.25-i*.08))
        beam(start,end,.085-i*.007,'bed')
        tip=(end[0]*1.4,end[1]+.55,end[2]*1.4)
        beam(end,tip,.045,'paint_shadow')
        beam(end,(end[0]*1.2+.24,end[1]+.7,end[2]*1.1-.15),.03,'bed')
    for i in range(5):
        a=i*math.tau/5
        beam((0,.3,0),(math.sin(a)*.65,.04,math.cos(a)*.65),.10,'bed')


def rock(variant):
    import random
    rng=random.Random(1837+variant)
    obj=ellipsoid((0,.45,0),(.95,.60,.88),'steel',2)
    for v in obj.data.vertices:
        radial=1+rng.uniform(-.15,.15)
        v.co.x*=radial;v.co.y*=radial
        v.co.z=max(-.45,v.co.z)*rng.uniform(.9,1.08)
    # Shallow split ledges make larger boulders read as fractured stone.
    for i in range(3):
        size=(rng.uniform(.25,.45),rng.uniform(.10,.20),rng.uniform(.3,.5))
        chip=ellipsoid((rng.uniform(-.45,.45),.25+i*.2,rng.uniform(-.35,.35)),size,'paint_shadow' if i%2 else 'accent',1)
    # Keep the existing unit footprint used by rock collider/terrain placement.
    for part in PARTS:
        bpy.context.view_layer.update()
    points=[part.matrix_world@v.co for part in PARTS for v in part.data.vertices]
    low=Vector(tuple(min(v[i] for v in points) for i in range(3)))
    high=Vector(tuple(max(v[i] for v in points) for i in range(3)))
    for part in PARTS:
        part.data.transform(part.matrix_world);part.matrix_world.identity()
        for v in part.data.vertices:
            v.co.x=(v.co.x-(low.x+high.x)/2)*2/(high.x-low.x)
            v.co.y=(v.co.y-(low.y+high.y)/2)*2/(high.y-low.y)
            v.co.z=(v.co.z-low.z)/(high.z-low.z)

    radius=max(math.hypot(v.co.x,v.co.y) for part in PARTS for v in part.data.vertices)
    for part in PARTS:
        for v in part.data.vertices:
            v.co.x/=radius;v.co.y/=radius


def fence(post):
    if post:
        box((0,0,0),(.16,1,.16),'bed',.018)
        box((0,.47,0),(.19,.08,.19),'steel',.02)
        for y in [-.25,.25]: tube((0,y,.092),.028,.025,'steel',(0,0,1),6)
    else:
        box((0,0,0),(1,.11,.09),'bed',.012)
        for x in [-.4,.4]: tube((x,0,.052),.024,.018,'steel',(0,0,1),6)


def windmill(blades=False):
    if blades:
        tube((0,0,0),.22,.22,'steel',(0,0,1))
        for i in range(3):
            angle=i*math.tau/3
            start=len(PARTS)
            beam((0,0,0),(0,2.1,0),.055,'steel')
            for y in [.9,1.2,1.5,1.8]: box((0,y,.02),(.42,.25,.06),'paint_light')
            for obj in PARTS[start:]:
                from mathutils import Matrix
                obj.matrix_world=Matrix.Rotation(-angle,4,'Y')@obj.matrix_world
    else:
        for x in [-.55,.55]:
            for z in [-.55,.55]:
                beam((x,0,z),(x*.25,5,z*.25),.07,'steel')
        for y in range(4):
            for z in [-.45,.45]: beam((-.50,y+.2,z),(.50,y+1.2,z),.035,'accent')
        box((0,.45,0),(1.5,.9,1.3),'paint_shadow')
        panel((0,.53,.67),(.65,.6,.07))
        tube((0,5,.3),.25,.70,'steel',(0,0,1))
        ladder(.65,.50,4.8)


def base(tier):
    bunker=tier==1
    width,depth,height=(8,6,3.27) if bunker else (9.2,5.7,3.6)
    wallheight=2.5 if bunker else 2.55
    box((0,.16,0),(width,.32,depth),'steel',.08)
    box((0,wallheight/2+.25,0),(width-.45,wallheight,depth-.50),'paint_shadow' if bunker else 'paint',.10)
    if bunker:
        box((0,2.96,0),(8,.62,5.9),'steel',.12)
        for x in [-2.95,2.95]: box((x,1.1,2.66),(1,1.6,.64),'steel',.08)
        box((0,2.02,2.80),(2.1,.3,.08),'dark')
        box((0,1.84,2.85),(2.25,.09,.18),'accent')
    else:
        for side in [-1,1]:
            roof=box((0,3.00,side*1.25),(9.2,.22,2.7),'steel',.02)
            roof.rotation_euler.x=side*.30
            for i in range(13):
                beam((-4.4+i*.73,3.39,0),(-4.4+i*.73,2.62,side*2.53),.025,'paint_light')
        for x in [-3,-1.8,1.8,3]:
            box((x,1.72,2.64),(.82,.62,.06),'dark')
            box((x,1.72,2.68),(.70,.5,.035),'glass_light')
            box((x,1.72,2.71),(.04,.53,.03),'steel')
            box((x,1.39,2.70),(.95,.08,.13),'accent')
    dz=2.82 if bunker else 2.64
    panel((0,.98,dz),(1.2,1.65,.10))
    for x in [-.69,.69]: box((x,1.03,dz+.04),(.12,1.95,.15),'accent')
    box((0,2.02,dz+.04),(1.5,.12,.15),'accent')
    box((.38,1,dz+.08),(.055,.2,.07),'steel')
    for side in [-1,1]:
        for i in range(7):
            box((side*(width/2-.19),1.4,-2.1+i*.7),(.08,2.2,.08),'paint_light')
        box((side*(width/2-.15),2.2,-1.3),(.07,.6,1.15),'dark')
        for i in range(5): box((side*(width/2-.10),1.98+i*.1,-1.3),(.035,.04,1.06),'steel')
    for x in [-2.5,2.5]:
        box((x,2.35,dz),(.42,.18,.15),'trim')
        box((x,2.34,dz+.085),(.3,.10,.025),'lamp')
    # Roof service hatch stays inside the established collider height.
    tube((1.5,3.22 if bunker else 3.32,-.4),.42,.07,'paint',sides=16)


def loot(kind):
    if kind=='repair_kit':
        box((0,.37,0),(1.45,.70,.82),'red',.08)
        for x in [-.55,.55]:
            box((x,.38,.42),(.09,.65,.04),'steel')
            box((x,.58,.46),(.14,.16,.06),'accent')
        for x in [-.25,.25]: box((x,.83,0),(.09,.23,.12),'trim')
        box((0,.96,0),(.59,.09,.12),'trim')
        box((0,.41,.43),(.34,.10,.03),'white')
        box((0,.41,.45),(.10,.34,.03),'white')
    elif kind=='fuel_cell':
        tube((0,.63,0),.32,1.18,'paint',sides=16)
        for y in [.1,.32,.96,1.2]:tube((0,y,0),.35,.06,'steel',sides=16)
        tube((0,1.28,0),.14,.12,'trim')
        tube((0,1.36,0),.2,.045,'amber')
        panel((0,.65,.32),(.22,.38,.06))
        for x in [-.26,.26]:beam((x,.25,0),(x,1.1,0),.035,'accent')
    elif kind=='circuit':
        box((0,.12,0),(1.5,.10,1),'paint',.015)
        for x,z in [(-.3,-.1),(.3,.2),(.35,-.25)]:
            box((x,.24,z),(.36,.14,.25),'trim')
            for i in range(5):
                for side in [-1,1]:box((x-.14+i*.07,.18,z+side*.16),(.03,.045,.10),'accent')
        for i in range(12):box((-.65+i*.115,.18,.46),(.06,.035,.12),'accent')
        for x in [-.65,.65]:
            for z in [-.4,.4]:tube((x,.19,z),.04,.03,'steel')
        for z in [-.3,-.1,.1]:box((-.53,.2,z),(.10,.10,.14),'steel')
    elif kind=='relic':
        tube((0,.14,0),.55,.28,'trim',sides=12)
        tube((0,.31,0),.47,.08,'accent',sides=12)
        ellipsoid((0,.6,0),(.25,.4,.25),'glass_light',1)
        for i in range(6):
            a=i*math.tau/6
            beam((math.sin(a)*.4,.3,math.cos(a)*.4),(math.sin(a)*.3,.95,math.cos(a)*.3),.045,'steel')
        tube((0,1,0),.34,.09,'accent',sides=12)
    else:
        box((0,.12,0),(1.2,.18,.85),'steel')
        for i in range(3):
            ob=box((-.3+i*.3,.3+i*.09,0),(.6,.10,.70),'paint_shadow' if i%2 else 'accent');ob.rotation_euler.z=i*.24
        tube((.32,.40,.13),.16,.35,'trim',(1,0,0),12)
        for i in range(8):
            a=i*math.tau/8
            box((-.4+math.sin(a)*.20,.34,math.cos(a)*.20),(.09,.12,.09),'steel',.008)


def projectile(kind,enemy):
    color='red' if enemy else 'accent'
    if kind=='grenade':
        ellipsoid((0,0,0),(.26,.32,.26),'paint_shadow')
        tube((0,.33,0),.10,.10,'steel')
        box((.10,.3,0),(.09,.1,.38),color)
        for y in [-.15,0,.15]:tube((0,y,0),.255,.025,'steel',sides=12)
    else:
        radius=.12 if kind=='rocket' else .045 if kind=='bullet' else .07
        length=1.1 if kind=='rocket' else .48 if kind=='bullet' else 1.0
        tube((0,0,0),radius,length,'paint_shadow' if kind=='rocket' else 'steel',sides=12)
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=radius,radius2=0,depth=radius*3,location=point((0,length/2+radius*1.5,0)))
        finish(bpy.context.object,color)
        for y in [-length*.4,length*.35]:tube((0,y,0),radius*1.06,.04,color)
        tube((0,-length/2-.02,0),radius*.65,.03,'dark')
        if kind!='bullet':
            for i in range(4):
                a=i*math.tau/4
                obj=box((math.sin(a)*radius*1.45,-length*.34,math.cos(a)*radius*1.45),(radius*.09,.28,radius*1.8),color,.004)
                obj.rotation_euler.z=-a


def brush(dead=False):
    for i in range(9):
        a=i*2.399;radius=.15+(i%3)*.18
        end=(math.sin(a)*radius,.42+(i%4)*.12,math.cos(a)*radius)
        beam((0,0,0),end,.015,'bed')
        if dead:
            beam(end,(end[0]+.15,end[1]+.16,end[2]+.1),.01,'bed')
            beam(end,(end[0]-.15,end[1]+.12,end[2]-.1),.01,'paint_shadow')
        else:
            for side in [-1,1]:
                leaf=ellipsoid((end[0]+side*.10,end[1]-.04,end[2]),(.20,.095,.14),'paint' if i%3 else 'paint_light',1)
                leaf.rotation_euler.y=side*.4


def grass(flowers=False):
    for i in range(12 if not flowers else 6):
        a=i*2.399;radius=.03+(i%3)*.065;height=.18+(i%5)*.055
        x,z=math.sin(a)*radius,math.cos(a)*radius
        if flowers:
            beam((x,0,z),(x,height,z),.008,'paint')
            for k in range(5):
                angle=k*math.tau/5
                ellipsoid((x+math.sin(angle)*.035,height,z+math.cos(angle)*.035),(.035,.014,.03),'white',1)
            ellipsoid((x,height+.01,z),(.016,.014,.016),'amber',1)
        else:
            mesh=bpy.data.meshes.new('tapered blade')
            verts=[point((x-.018,0,z)),point((x+.018,0,z)),point((x+.035,height*.6,z+.015)),point((x+.02,height,z+.03))]
            mesh.from_pydata(verts,[],[(0,1,2),(0,2,3),(2,1,0),(3,2,0)])
            obj=bpy.data.objects.new('blade',mesh);bpy.context.collection.objects.link(obj);finish(obj,'paint_light' if i%3==0 else 'paint')


def structure(kind):
    if kind in ['cliffFaces','cliffStrata','earthStructure','ruinStructure','scarStructure']:
        color='accent' if kind=='earthStructure' else 'steel'
        obj=box((0,0,0),(1,1,1),color,.065)
        if kind!='earthStructure':
            for i in range(3):
                # Inset fault strata and exposed angular stone, kept inside unit bounds.
                box((0,-.32+i*.30,.47),(.86,.045,.04),'paint_shadow',.01)
            if kind=='ruinStructure':
                for x in [-.24,.24]: beam((x,.20,.40),(x,.49,.42),.017,'trim')
    elif kind=='woodStructure':
        for i in range(5):box((-.40+i*.20,0,0),(.19,1,1),'bed' if i%2 else 'paint_shadow',.009)
        for y in [-.38,.38]:
            box((0,y,.48),(.98,.045,.035),'accent',.005)
            for x in [-.4,0,.4]:tube((x,y,.50),.012,.008,'steel',(0,0,1),6)
    else:
        color='red' if kind=='redStructure' else 'paint_shadow' if kind=='ironStructure' else 'steel'
        box((0,0,0),(.98,.98,.98),color,.035)
        for x in [-.44,.44]:
            box((x,0,.493),(.025,.90,.012),'paint_light',.002)
            for y in [-.42,.42]:tube((x,y,.50),.018,.01,'accent',(0,0,1),6)
        for y in [-.44,.44]:box((0,y,.493),(.89,.02,.012),'paint_light',.002)


def pump_arm():
    box((1.4,0,0),(4.8,.26,.32),'paint_shadow')
    for z in [-.18,.18]:
        box((1.4,.10,z),(4.6,.055,.05),'steel')
        for x in [-.7,0,.8,1.6,2.4,3.3]:
            tube((x,0,z),.045,.02,'accent',(0,0,1),6)
    # The curved horsehead replaces the old rectangular hanging weight.
    for i in range(5):
        a=i*.23
        box((3.5+math.sin(a)*.32,-.1-i*.27,0),(.48,.34,.48),'red',.035)
    tube((0,0,0),.24,.65,'steel',(0,0,1))
    for z in [-.35,.35]:tube((0,0,z),.14,.04,'accent',(0,0,1),12)


def save_model(name, builder):
    PARTS.clear();builder()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS: obj.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    obj=PARTS[0];obj.name=name
    obj.data.transform(obj.matrix_world);obj.matrix_world.identity()
    if name in POOL_SOURCE_INDEX:
        source=json.loads((ROOT/'data/visual_models/world_72841.json').read_text())['meshes'][POOL_SOURCE_INDEX[name]]['attributes']['position']
        source_low=[min(source[axis::3]) for axis in range(3)]
        source_high=[max(source[axis::3]) for axis in range(3)]
        target_low=point((source_low[0],source_low[1],source_high[2]))
        target_high=point((source_high[0],source_high[1],source_low[2]))
        low=Vector(tuple(min(v.co[axis] for v in obj.data.vertices) for axis in range(3)))
        high=Vector(tuple(max(v.co[axis] for v in obj.data.vertices) for axis in range(3)))
        for v in obj.data.vertices:
            for axis in range(3):
                v.co[axis]=target_low[axis]+(v.co[axis]-low[axis])/(high[axis]-low[axis])*(target_high[axis]-target_low[axis])
    tri=obj.modifiers.new('Export triangulation','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    bpy.ops.wm.obj_export(filepath=str(OUT/(name+'.obj')),export_selected_objects=True,export_materials=True,export_uv=True,export_normals=True,forward_axis='NEGATIVE_Z',up_axis='Y')
    return obj


def main():
    global MATERIAL
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    build_player.OUT=OUT;MATERIAL=build_player.palette_material();MATERIAL.name='WorldPickupPalette'
    builders={'grazer':sheep,'house':house,'well':well,'market_stall':stall,'utility_pole':pole,'wreck':wreck,
              'barrelInstances':barrel,'crateInstances':lambda:crate((0,-.4,0)), 'tankInstances':tank,'satellite_dish':dish, 'deadTrees':dead_tree,
              'fencePosts':lambda:fence(True),'fenceRails':lambda:fence(False),
              'windmill':windmill,'windmill_blades':lambda:windmill(True),
              'BunkerAuthored':lambda:base(1),'BarracksAuthored':lambda:base(2)}
    for i,name in enumerate(['rockMass0','rockMass1','rockMass2','rockMass3','rockMass4','rockMass5','rockInstances','stoneInstances']):
        builders[name]=lambda i=i:rock(i)
    for name in ['watchtower','water_tower','factory','crane','refinery','pumpjack','satellite']:
        builders['detail_'+name]=lambda name=name:machinery(name)
    for name in ['scrap','circuit','relic','repair_kit','fuel_cell']:
        builders['loot_'+name]=lambda name=name:loot(name)
    for kind in ['bullet','sabot','rocket','grenade']:
        for enemy in [False,True]:
            name='projectile_'+('enemy_' if enemy else '')+kind
            builders[name]=lambda kind=kind,enemy=enemy:projectile(kind,enemy)
    builders['pumpjack_arm']=pump_arm
    builders.update({'scrubInstances':brush,'deadBrushInstances':lambda:brush(True),'grassTufts':grass,'flowerInstances':lambda:grass(True)})
    for name in ['ironStructure','metalStructure','woodStructure','redStructure','earthStructure','ruinStructure','scarStructure','cliffFaces','cliffStrata']:
        builders[name]=lambda name=name:structure(name)
    objects=[save_model(name,builder) for name,builder in builders.items()]
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(GAME),export_format='GLB',export_yup=True,use_selection=True)
    stats={obj.name:{'triangles':len(obj.data.polygons),'surfaces':len(obj.data.materials)} for obj in objects}
    (OUT/'stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    for i,obj in enumerate(objects):obj.location=((i%5)*15,(i//5)*15,0)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'world_quality.blend'))
    print('WORLD_QUALITY_EXPORTED',len(objects),sum(x['triangles'] for x in stats.values()))

if __name__=='__main__':main()
