"""Run through Blender MCP. Reuse military builders, preserve the existing scene.

Two geometry variants per machine; palette slots support cheap runtime recoloring.
No drones or motorcycles are rebuilt. Runtime animation contracts are retained.
"""
from pathlib import Path
import sys, json, math, importlib.util, shutil
sys.dont_write_bytecode = True
import bpy, mathutils
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/enemies_revised'
REVIEW=ROOT/'docs/enemy-vehicle-review'
STYLE=json.loads((ROOT/'data/enemy_vehicle_styles.json').read_text())
TRIANGLE_BUDGET=2400
BOSS_TRIANGLE_BUDGET=json.loads((ROOT/'data/leviathan_geometry.json').read_text())['triangle_budget']

def module(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts/blender'/f'{name}.py')
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

api=module('build_military_enemies');api.mathutils=mathutils
body=module('enemy_vehicle_bodywork')


WHEEL_SEGMENTS = 12
RIM_SEGMENTS = 8


def wheel(p,name,x,y,z,r=.42,width=.22):
    # A four-ring tyre keeps its rounded shoulder. Facet shades replace tiny
    # tread cubes; visible rim discs replace stacked cylinders and lug holes.
    rings=[(-width*.5,r*.87),(-width*.37,r),(width*.37,r),(width*.5,r*.87)]
    vertices=[(xx,math.cos(i*math.tau/WHEEL_SEGMENTS)*rr,math.sin(i*math.tau/WHEEL_SEGMENTS)*rr) for xx,rr in rings for i in range(WHEEL_SEGMENTS)]
    faces=[tuple(reversed(range(WHEEL_SEGMENTS)))]
    for ring in range(len(rings)-1):
        for i in range(WHEEL_SEGMENTS):
            j=(i+1)%WHEEL_SEGMENTS
            faces.append((ring*WHEEL_SEGMENTS+i,ring*WHEEL_SEGMENTS+j,(ring+1)*WHEEL_SEGMENTS+j,(ring+1)*WHEEL_SEGMENTS+i))
    faces.append(tuple(range((len(rings)-1)*WHEEL_SEGMENTS,len(rings)*WHEEL_SEGMENTS)))
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    tyre=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(tyre)
    tyre.parent=p;tyre.location=(x,y,z);api.finish(tyre,'rubber')
    uv=tyre.data.uv_layers.active
    for face in list(tyre.data.polygons)[1+WHEEL_SEGMENTS:1+2*WHEEL_SEGMENTS:2]:
        for loop in face.loop_indices:uv.data[loop].uv=(.375,.625)
    side=1 if x>0 else -1
    face=x+side*(width*.5+.006)
    parts=[api.disc(p,'Rim',(face,y,z),r*.61,'steel',(0,side*math.pi/2,0),RIM_SEGMENTS),
           api.disc(p,'Hub',(face+side*.006,y,z),r*.24,'shadow',(0,side*math.pi/2,0),RIM_SEGMENTS)]
    api.join_into(tyre,parts)
    return tyre


def facet_paint(obj,color):
    result=original_finish(obj,color)
    if color=='paint':
        # Separate top/side/underbody values, like the authored player pickup.
        for face in obj.data.polygons:
            normal=obj.rotation_euler.to_matrix()@face.normal
            slot=1 if normal.z>.65 else 2 if normal.z<-.3 else 0
            for loop in face.loop_indices:obj.data.uv_layers.active.data[loop].uv=((slot+.5)/4,.125)
    # Palette texture supplies color; avoid double tint in external GLB viewers.
    for attribute in list(obj.data.color_attributes):obj.data.color_attributes.remove(attribute)
    return result

original_finish=api.finish
api.finish=facet_paint;api.wheel=wheel
body.install(vars(api))
FACTORIES={'buggy':body.buggy,'raider':body.raider,'jammerTruck':lambda:body.utility_truck('jammerTruck','jammer'),
           'repairCrawler':body.crawler,'minelayer':lambda:body.utility_truck('minelayer','mine'),'boss':body.boss}


def web_mesh(parent):
    positions=[];normals=[];slots=[]
    bpy.context.view_layer.update()
    for obj in parent.children:
        if obj.type!='MESH':continue
        obj.data.calc_loop_triangles()
        matrix=obj.matrix_world
        normal_matrix=matrix.to_3x3().inverted().transposed()
        for triangle in obj.data.loop_triangles:
            normal=(normal_matrix@triangle.normal).normalized()
            for loop_id in triangle.loops:
                loop=obj.data.loops[loop_id]
                vertex=matrix@obj.data.vertices[loop.vertex_index].co
                uv=obj.data.uv_layers.active.data[loop_id].uv
                positions.extend(round(v,5) for v in vertex)
                normals.extend(round(v,5) for v in normal)
                slots.append(int(uv.x*4)+int(uv.y*4)*4)
    return {'positions':positions,'normals':normals,'slots':slots,'triangles':len(slots)//3,'parts':len(parent.children)}


def setup(preserve=False):
    global previous,scene,web,stats
    OUT.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)
    previous=bpy.context.window.scene
    scene=bpy.data.scenes.new('Enemy Vehicle Revision');bpy.context.window.scene=scene
    # Load the existing atlas without touching the legacy assets.
    image=bpy.data.images.load(str(ROOT/'assets/actors/military_enemies_palette.png'),check_existing=False)
    api.MAT=bpy.data.materials.new('EnemyRevisionPalette');api.MAT.use_nodes=True
    shader=api.MAT.node_tree.nodes['Principled BSDF'];shader.inputs['Roughness'].default_value=.86
    texture=api.MAT.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image;texture.interpolation='Closest'
    api.MAT.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
    web={'style':STYLE,'palette':[list(v[:3]) for v in api.PALETTE.values()],'models':{}}
    stats={}
    if preserve and (REVIEW/'models.js').exists():
        existing=(REVIEW/'models.js').read_text().removeprefix('window.REVIEW_DATA=').strip().removesuffix(';')
        web['models']=json.loads(existing)['models']
        stats=json.loads((OUT/'stats.json').read_text())


def build_one(name,variant):
    # Reuse names required by optimize/animation; rename only the exported root.
    for obj in list(scene.objects):bpy.data.objects.remove(obj,do_unlink=True)
    p=body.boss(variant) if name=='boss' else FACTORIES[name]()
    body.variant_details(p,variant)
    api.optimize(p);api.bake_scale(p,STYLE['models'][name]['scale'])
    bpy.context.view_layer.update();api.bake_object_transforms([p])
    if name=='boss':api.align_boss_components(p)
    api.ground_model(p);api.recalculate_normals([p])
    key=name+'_'+variant;p.name=key
    data=web_mesh(p)
    assert data['triangles']<(BOSS_TRIANGLE_BUDGET if name=='boss' else TRIANGLE_BUDGET),(key,data['triangles'])
    assert data['parts']<=7,(key,data['parts'])
    web['models'][key]=data;stats[key]={k:data[k] for k in ('triangles','parts')}
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True)
    runtime=ROOT/'assets/actors/enemies_revised';runtime.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(OUT/(key+'.glb'),runtime/(key+'.glb'))
    bpy.data.libraries.write(str(OUT/(key+'.blend')),{scene},path_remap='RELATIVE')
    print('VEHICLE_REVISION',key,stats[key])


def finish():
    (REVIEW/'models.js').write_text('window.REVIEW_DATA='+json.dumps(web,separators=(',',':'))+';\n')
    (OUT/'stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    bpy.context.window.scene=previous
    for obj in list(scene.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.scenes.remove(scene)
