"""Military field props and fortified enemy sites, authored in game units."""
import sys, json
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
import build_player
from pickup_geometry import MeshBuilder
from build_equipment import box,tube,beam,crate
import field_prop_detail
OUT=ROOT/'assets/models/field_props'
GAME=ROOT/'assets/actors/military_field_props.glb'
TYPES=['garrison_3','mine','pickup_fuel','pickup_salvage','heal_cart']
def garrison(tier):
    scale=.95+(tier-1)*.05
    body,roof,tower=MeshBuilder(),MeshBuilder(),MeshBuilder()
    box(body,(0,.25,0),(8.6,.5,8.4),'paint_shadow')
    box(body,(0,1.95,0),(7.0,3.4,6.2),'steel')
    for x in [-3.15,3.15]:
        box(body,(x,1.5,0),(.65,2.6,7.4),'paint')
        for z in [-3.5,-1.4,1.4,3.5]: box(body,(x,1.45,z),(.82,2.9,.25),'paint_shadow')
    box(body,(0,1.55,3.12),(2.8,2.4,.10),'dark')
    for x in [-1.5,1.5]: box(body,(x,1.55,3.21),(.18,2.75,.18),'accent')
    box(body,(0,2.95,3.22),(3.1,.18,.18),'accent')
    for z in [-3.2,3.2]:
        for x in [-2.55,2.55]:
            box(body,(x,2.75,z),(.95,.52,.12),'dark')
            box(body,(x,2.46,z), (1.12,.10,.18),'paint_light')
    for x in [-3.6,3.6]:
        for z in [-2.7,2.7]: box(body,(x,.6,z),(1.0,.75,1.2),'paint_shadow')
    box(roof,(0,3.78,0),(7.45,.3,6.75),'paint_light')
    for x in [-3.35,3.35]: box(roof,(x,4.06,0),(.16,.55,6.3),'paint')
    box(roof,(0,4.04,-3.12),(6.6,.5,.16),'paint')
    for x in [-2.1,0,2.1]: box(roof,(x,3.97,0),(1.2,.16,2.7),'trim')
    # Tall exhaust stacks and a small communications mast keep the fortress silhouette.
    for i in range(tier+1):
        x=-2.4+i*1.6
        tube(tower,(x,6.1,-2.35),.42,4.3,'paint_shadow',segments=8)
        for y in [4.5,6.9,8.2]: tube(tower,(x,y,-2.35),.49,.18,'steel',segments=8)
        tube(tower,(x,8.28,-2.35),.33,.03,'dark',segments=8)
    box(tower,(1.5,4.42,1.0),(2.2,.75,1.5),'paint')
    tube(tower,(1.5,4.88,1.0),.5,.22,'steel',segments=12)
    tube(tower,(1.5,5.16,1.85),.16,1.8,'trim',(0,0,1),10)
    box(tower,(1.5,5.17,1.0),(1.05,.48,.8),'paint_light')
    if tier == 3:
        field_prop_detail.factory(body, roof)
    combined=MeshBuilder()
    for b in [body,roof,tower]:
        offset=len(combined.vertices)
        combined.vertices.extend(tuple(v*scale for v in p) for p in b.vertices)
        combined.faces.extend(tuple(offset+i for i in face) for face in b.faces)
        combined.colors.extend(b.colors)
    return [('Fortification',combined,(0,0,0))]
def build(name):
    if name.startswith('garrison'):return garrison(int(name[-1]))
    b=MeshBuilder(); parts=[]
    if name == 'mine':
        tube(b,(0,.15,0),.66,.30,'paint_shadow',segments=12)
        tube(b,(0,.33,0),.55,.12,'paint',segments=12)
        tube(b,(0,.405,0),.28,.04,'trim',segments=10)
        for x in [-.45,.45]: box(b,(x,.408,0),(.10,.025,.42),'accent')
        field_prop_detail.mine(b)
        signal=MeshBuilder();tube(signal,(0,.447,0),.16,.045,'white',segments=12)
        return [('MineBody',b,(0,0,0)),('MineSignal',signal,(0,0,0))]
    if name=='pickup_fuel':
        box(b,(0,.52,0),(.60,.92,.44),'paint')
        for y in [.16,.84]:box(b,(0,y,0),(.62,.07,.46),'steel')
        for x in [-.18,.18]:box(b,(x,1.07,0),(.08,.22,.13),'trim')
        box(b,(0,1.18,0),(.44,.08,.13),'trim')
        tube(b,(.19,1.03,.12),.08,.08,'accent',segments=8)
        beam(b,(-.19,.25,.235),(.19,.74,.235),.028,'accent')
        beam(b,(.19,.25,.235),(-.19,.74,.235),.028,'accent')
    elif name=='pickup_salvage':
        crate(b,(0,.36,0),(.70,.60,.62),'bed')
        for x,z in [(-.18,-.12),(.17,.13),(0,.05)]:tube(b,(x,.73,z),.105,.30,'steel',(1,0,0),8)
        box(b,(.13,.72,-.15),(.27,.18,.18),'accent')
    elif name=='heal_cart':
        from heal_cart_bodywork import build as build_ambulance
        return build_ambulance()
    field_prop_detail.supply(b, name)
    return [('Body',b,(0,0,0))]+parts

def main():
    OUT.mkdir(parents=True,exist_ok=True); GAME.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    build_player.OUT=OUT;material=build_player.palette_material();material.name='Field_Palette'
    stats={}
    for name in TYPES:
        root=bpy.data.objects.new('FIELD_'+name,None);bpy.context.collection.objects.link(root)
        for label,builder,at in build(name):
            mesh=builder.finish(name+'_'+label,material);obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj);obj.parent=root;obj.location=(at[0],-at[2],at[1])
        stats[name]={'triangles':sum(len(obj.data.polygons) for obj in root.children),'mesh_objects':len(root.children),'materials':1}
        bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
        for obj in root.children:obj.select_set(True)
        bpy.ops.wm.obj_export(filepath=str(OUT/(name+'.obj')),export_selected_objects=True,export_materials=True,export_uv=True,export_normals=True,export_triangulated_mesh=True,forward_axis='NEGATIVE_Z',up_axis='Y')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(GAME),export_format='GLB',use_selection=True,export_materials='EXPORT',export_yup=True)
    for i,root in enumerate([o for o in bpy.context.scene.objects if o.parent is None]):root.location=((i%4)*12,(i//4)*12,0)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'field_props.blend'))
    (OUT/'stats.json').write_text(json.dumps(stats,indent=2)+'\n')
if __name__=='__main__':main()
