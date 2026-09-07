"""Authored compact military equipment library; Blender Z-up, runtime +Z forward."""
import json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import build_player
from pickup_geometry import MeshBuilder
from equipment_detail import detail
from equipment_panels import panel
OUT = ROOT / 'assets/models/equipment'
TYPES = ['turret','repair_station','ammo_feed','cargo_rack','salvage_arm','fuel_pump','anti_tank_station','anti_air_station','reinforced_hitch', 'akTurret','armor','assaultRifle','bazooka','bumper','counterDroneJammer','flamethrower','grenadeLauncher','mineHacker','minigun','missileRack','radar','railgun','treasury','workshop']
AA_MOUNT_SCALE = 0.88
GUNS = {'turret','anti_tank_station','anti_air_station','akTurret','assaultRifle','bazooka','flamethrower','grenadeLauncher','minigun','missileRack','railgun'}
def p(v): return (v[0], -v[2], v[1])
def box(b, at, size, color='paint'): panel(b, p(at), (size[0],size[2],size[1]), color)
def tube(b, at, radius, length, color='steel', axis=(0,1,0), segments=10, tip=None):
    n=Vector(p(axis)).normalized(); u=n.cross(Vector((1,0,0)) if abs(n.x)<.9 else Vector((0,1,0))).normalized(); v=n.cross(u); c=Vector(p(at))
    rings=[]
    for d,r in [(-length/2,radius),(length/2,radius if tip is None else tip)]:
        rings.append([tuple(c+n*d+(u*math.cos(i*math.tau/segments)+v*math.sin(i*math.tau/segments))*r) for i in range(segments)])
    b.loft(rings,color)
def beam(b,a,c,width,color='steel'):
    a,c=Vector(a),Vector(c); tube(b,(a+c)/2,width,(c-a).length,color,tuple(c-a),4)
def crate(b,at,size=(.74,.65,.70),color='paint'):
    box(b,at,size,color)
    x,y,z=at; w,h,d=size
    box(b,(x,y+h/2+.025,z),(w+.035,.05,d+.035),'paint_light')
    for side in [-1,1]:
        box(b,(x+side*w*.30,y,z),( .035,h+.07,d+.05),'trim')
        box(b,(x+side*w*.22,y+h*.23,z+d/2+.02),(.09,.11,.035),'accent')
    box(b,(x,y+h*.12,z+d/2+.04),(.20,.05,.045),'steel')
def gun(b,typ):
    tube(b,(0,.30,0),.29,.34,'paint_shadow')
    box(b,(0,.52,0),(.61,.40,.57),'paint')
    box(b,(0,.745,-.06),(.46,.06,.42),'paint_light')
    if typ=='bazooka':
        # Single recoilless launcher: long fat tube, open rear bell, shoulder guard.
        tube(b,(0,.68,.50),.23,1.75,'paint',(0,0,1),12)
        for z in [-.39,1.40]:
            tube(b,(0,.68,z),.29,.16,'steel',(0,0,1),12)
            tube(b,(0,.68,z+(.085 if z>0 else -.085)),.205,.012,'dark',(0,0,1),12)
        box(b,(0,.40,.22),(.56,.12,.75),'paint_shadow')
        box(b,(-.30,.93,.35),(.13,.12,.48),'trim')
        return
    if typ=='anti_air_station':
        # Elevated twin autocannon with separated barrels and rear tracking radar.
        box(b,(0,.73,0),(.95,.32,.68),'paint_shadow')
        for x in [-.38,.38]:
            tube(b,(x,.88,.93),.065,1.62,'trim',(0,.22,1),10)
            tube(b,(x,1.06,1.73),.10,.18,'steel',(0,.22,1),10)
            crate(b,(x*1.65,.51,-.08),(.30,.45,.63),'bed')
        tube(b,(0,1.06,-.39),.035,.70,'steel')
        box(b,(0,1.42,-.39),(.78,.36,.09),'glass')
        return
    count=1
    r=.072; length=1.13
    if typ in ['anti_tank_station','railgun']: r=.095; length=1.52
    if typ in ['bazooka','grenadeLauncher']: r=.16; length=.97
    if typ=='minigun': count=6; r=.034
    if typ=='missileRack':
        for x in [-.21,.21]:
            for y in [.49,.78]:
                tube(b,(x,y,.24),.135,1.05,'paint_shadow',(0,0,1),8)
                tube(b,(x,y,.78),.11,.16,'accent',(0,0,1),8,0)
        return
    for i in range(count):
        x=(i-(count-1)/2)*.26 if count==2 else math.sin(i*math.tau/6)*.12 if count==6 else 0
        y=.58+(math.cos(i*math.tau/6)*.12 if count==6 else 0)
        tube(b,(x,y,.36+length/2),r,length,'trim',(0,0,1))
        tube(b,(x,y,.37+length),r*1.35,.09,'steel',(0,0,1))
        tube(b,(x,y,.425+length),r*.75,.014,'dark',(0,0,1))
    if typ=='railgun':
        for x in [-.15,.15]: box(b,(x,.58,1.01),(.08,.15,1.22),'accent')
    if typ=='flamethrower':
        for x in [-.24,.24]: tube(b,(x,.52,-.30),.13,.52,'red')
    else: crate(b,(-.40,.42,-.08),(.23,.33,.42),'bed')
    for x in [-.21,.21]: box(b,(x,.75,.10),(.025,.13,.055),'trim')
def _build(typ):
    base, upper=MeshBuilder(),MeshBuilder()
    if typ=='bumper':
        box(base,(0,.20,0),(3.32,.32,.28),'paint_shadow')
        for x in [-1.40,1.40]: box(base,(x,.48,.02),(.14,.63,.18),'steel')
        box(base,(0,.76,.02),(2.93,.12,.16),'steel')
        for x in [-.55,.55]: tube(base,(x,.07,.18),.12,.055,'accent',(0,0,1),8)
        return base,upper
    box(base,(0,.06,0),(.78,.12,.73),'paint_shadow')
    for x in [-.30,.30]:
        for z in [-.27,.27]: tube(base,(x,.131,z),.032,.02,'accent',segments=6)
    if typ in GUNS:
        tube(base,(0,.16,0),.36,.10,'steel',segments=12)
        gun(upper,typ)
        if typ == 'anti_air_station':
            upper.vertices = [tuple(value * AA_MOUNT_SCALE for value in vertex) for vertex in upper.vertices]
    elif typ in ['cargo_rack','ammo_feed','treasury']:
        crate(base,(0,.44,0),(.75,.61,.70),'accent' if typ=='ammo_feed' else 'paint')
        if typ=='cargo_rack':
            for x in [-.37,.37]: box(base,(x,.84,0),(.035,.20,.70),'steel')
        if typ=='treasury':
            tube(base,(0,.48,.373),.12,.035,'steel',(0,0,1),8)
            box(base,(0,.80,0),(.70,.06,.64),'trim')
    elif typ in ['repair_station','workshop']:
        crate(base,(0,.42,0),(.77,.57,.61))
        box(base,(0,.75,0),(.83,.08,.73),'steel')
        for y in [.25,.43,.61]: box(base,(0,y,.315),(.48,.027,.025),'accent')
        box(base,(-.22,.86,0),(.18,.16,.21),'trim')
        box(base,(-.22,.95,0),(.25,.055,.21),'steel')
        for x in [.11,.26]: tube(base,(x,.80,.08),.028,.21,'accent',(0,0,1),6)
    elif typ=='fuel_pump':
        tube(base,(-.10,.58,0),.28,.87,'paint',segments=12)
        for y in [.25,.82]: tube(base,(-.10,y,0),.29,.065,'steel',segments=12)
        tube(base,(-.10,1.04,0),.08,.065,'accent',segments=8)
        box(base,(.27,.52,0),(.22,.49,.38),'trim')
        box(base,(.27,.69,.20),(.14,.12,.025),'glass')
        for a,c in [((.33,.82,0),(.46,.69,0)),((.46,.69,0),(.46,.24,0)),((.46,.24,0),(.29,.20,0))]: beam(base,a,c,.032,'rubber')
    elif typ=='salvage_arm':
        tube(base,(0,.23,0),.28,.20,'steel')
        beam(base,(0,.24,0),(0,1.1,-.23),.12,'accent')
        beam(base,(0,1.1,-.23),(0,.99,.58),.10,'paint')
        beam(base,(0,.47,-.08),(0,.96,.36),.038,'steel')
        for x in [-.16,.16]:
            beam(base,(0,.99,.58),(x,.66,.61),.045,'steel')
            beam(base,(x,.66,.61),(x*.3,.55,.63),.045,'trim')
    elif typ == 'armor':
        for z in [-.22,0,.22]:
            box(base,(0,.46,z),(.75,.64,.09),'paint')
            box(base,(0,.79,z),(.76,.045,.10),'steel')
            for x in [-.28,.28]: tube(base,(x,.33,z+.05),.025,.025,'accent',(0,0,1),6)
    elif typ=='reinforced_hitch':
        for x in [-.25,.25]: box(base,(x,.22,0),(.15,.20,.72),'steel')
        box(base,(0,.23,-.27),(.64,.16,.16),'paint')
        tube(base,(0,.26,.23),.18,.16,'accent',segments=10)
        tube(base,(0,.35,.23),.085,.17,'trim',segments=8)
    elif typ in ['radar','counterDroneJammer','mineHacker']:
        crate(base,(0,.37,0),(.64,.47,.56))
        tube(base,(0,.77,0),.055,.55,'steel',segments=8)
        if typ=='radar':
            # A lightweight segmented radar dish with a feed stalk.
            tube(base,(0,1.10,0),.40,.10,'paint_light',(0,0,1),12,.30)
            beam(base,(0,1.1,.05),(0,1.1,.34),.02,'accent')
        else:
            for x in [-.22,.22]:
                tube(base,(x,.97,0),.022,.73,'trim',segments=6)
                for y in [.76,.90,1.04]: box(base,(x,y,0),(.18,.035,.035),'steel')
        box(base,(0,.42,.295),(.29,.17,.025),'glass')
        for x in [-.10,0,.10]: tube(base,(x,.24,.30),.018,.025,'lamp',(0,0,1),6)
    return base,upper

def build(typ):
    base, upper = _build(typ)
    detail(typ, base, upper, box, tube, beam)
    return base, upper

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    build_player.OUT=OUT
    material=build_player.palette_material(); material.name='Military_Equipment_Palette'
    stats={}
    for typ in TYPES:
        root=bpy.data.objects.new('EQUIPMENT_'+typ,None); bpy.context.collection.objects.link(root)
        base,upper=build(typ)
        for label,builder in [('BASE',base),('MOVING',upper)]:
            if not builder.faces: continue
            mesh=builder.finish(typ+'_'+label,material)
            obj=bpy.data.objects.new(label,mesh); bpy.context.collection.objects.link(obj); obj.parent=root
        stats[typ]={'triangles':sum(len(c.data.polygons) for c in root.children),'meshes':len(root.children),'materials':1}
        bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
        for child in root.children: child.select_set(True)
        bpy.ops.wm.obj_export(filepath=str(OUT/(typ+'.obj')),export_selected_objects=True,export_materials=True,export_uv=True,export_normals=True,export_triangulated_mesh=True,forward_axis='NEGATIVE_Z',up_axis='Y')
    bpy.ops.object.select_all(action='SELECT')
    # Lay out the editable library so all models can be reviewed in Blender.
    roots = [obj for obj in bpy.context.scene.objects if obj.parent is None]
    for index, obj in enumerate(roots):
        obj.location = ((index % 5) * 3.6, (index // 5) * 3.4, 0)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'equipment.blend'))
    for obj in roots: obj.location = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/vehicles/military_equipment.glb'),export_format='GLB',use_selection=True,export_materials='EXPORT',export_yup=True)
    (OUT/'stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    print('EQUIPMENT_EXPORTED',len(stats),stats)
if __name__=='__main__': main()
