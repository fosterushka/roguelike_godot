"""Build the baked, low-poly environment library used directly by Godot MultiMeshes."""
import bpy, os, math, shutil
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "environment")

def material(name, rgb):
    value = bpy.data.materials.new(name); value.diffuse_color = (*rgb, 1); value.use_nodes = True
    value.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
    value.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .92
    return value

OLIVE = material("olive", (.31,.37,.24)); NEEDLE = material("needle_dark", (.16,.23,.16)); BARK = material("bark", (.27,.22,.16))
BIRCH = material("birch_bark", (.62,.58,.46)); MARK = material("birch_marks", (.18,.17,.13)); SAND = material("sand", (.58,.52,.38))
STONE = material("stone", (.42,.41,.35)); IRON = material("iron", (.24,.28,.26)); RUST = material("rust", (.48,.28,.18))
PALETTE = material("military_environment_palette", (1,1,1))
PALETTE_COLORS = [OLIVE, NEEDLE, BARK, BIRCH, MARK, SAND, STONE, IRON, RUST]
def palette_texture():
    image=bpy.data.images.new("military_environment_palette", len(PALETTE_COLORS), 1, alpha=True)
    pixels=[]
    for source in PALETTE_COLORS: pixels += list(source.diffuse_color[:])
    image.pixels= pixels; image.filepath_raw=os.path.join(OUT,"military_environment_palette.png"); image.file_format='PNG'; image.save()
    runtime_dir=os.path.join(ROOT,"assets","environment")
    os.makedirs(runtime_dir,exist_ok=True)
    shutil.copyfile(image.filepath_raw,os.path.join(runtime_dir,"military_environment_palette.png"))
    nodes=PALETTE.node_tree.nodes; links=PALETTE.node_tree.links
    texture=nodes.new("ShaderNodeTexImage"); texture.image=image; texture.interpolation='Closest'
    # GLB and OBJ both use the same non-emissive palette texture for normal lighting.
    links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    return texture
def use_obj_palette(texture):
    nodes=PALETTE.node_tree.nodes; links=PALETTE.node_tree.links; base=nodes["Principled BSDF"].inputs["Base Color"]
    for link in list(base.links): links.remove(link)
    links.new(texture.outputs["Color"], base)

def cone(name, point, height, bottom, top, mat, sides=8):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=bottom, radius2=top, depth=height, location=point)
    item = bpy.context.object; item.name = name; item.data.materials.append(mat); return item
def ico(name, point, scale, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=point)
    item=bpy.context.object; item.name=name; item.scale=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); item.data.materials.append(mat); return item
def cube(name, point, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    item=bpy.context.object; item.name=name; item.scale=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); item.data.materials.append(mat); return item
def limb(name, start, end, radius, mat):
    start,end=Vector(start),Vector(end); delta=end-start
    item=cone(name,(start+end)*.5,delta.length,radius,radius*.56,mat,6)
    item.rotation_mode='QUATERNION'; item.rotation_quaternion=Vector((0,0,1)).rotation_difference(delta.normalized()); return item
def join(name, parts):
    bpy.ops.object.select_all(action='DESELECT')
    for item in parts: item.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); parts[0].name=name; return parts[0]
def bake(item):
    # Godot runtime takes Mesh only and intentionally ignores GLB node transforms.
    item.data.transform(item.matrix_world); item.matrix_world.identity()
def collapse_palette(item):
    mesh=item.data
    colors=mesh.color_attributes.new("COLOR", 'BYTE_COLOR', 'CORNER')
    uvs=mesh.uv_layers.new(name="UVMap")
    source=[slot.diffuse_color[:] for slot in mesh.materials]
    for polygon in mesh.polygons:
        color=source[polygon.material_index] if polygon.material_index < len(source) else (1,1,1,1)
        palette_index=min(range(len(PALETTE_COLORS)), key=lambda i: sum((color[c]-PALETTE_COLORS[i].diffuse_color[c])**2 for c in range(3)))
        uv=((palette_index+.5)/len(PALETTE_COLORS), .5)
        for index in polygon.loop_indices:
            colors.data[index].color=color; uvs.data[index].uv=uv
        polygon.material_index=0
    mesh.materials.clear(); mesh.materials.append(PALETTE)

def spruce():
    parts=[cone("SpruceTrunk",(0,0,2.65),5.3,.32,.13,BARK,7)]
    for tier in range(6):
        z=1.35+tier*.9; radius=2.12-tier*.285
        # Wide-bottom, pointed-top cones make a crisp conifer silhouette.
        parts.append(cone("SpruceWhorl",(0,0,z),1.72,radius,0,NEEDLE if tier%2 else OLIVE,8))
        for spoke in range(5):
            angle=spoke*math.tau/5+tier*.34
            parts.append(limb("SpruceBranch",(0,0,z),(.72*radius*math.cos(angle),.72*radius*math.sin(angle),z+.08),.075,BARK))
    return join("spruceTrees",parts)

def birch():
    parts=[cone("BirchTrunk",(0,0,3.15),6.3,.29,.15,BIRCH,8)]
    # Bark marks are shallow dark plates, visible without texture reads.
    for i in range(10):
        a=i*2.41; z=.65+(i%6)*.78; parts.append(cube("BirchMark",(.285*math.cos(a),.285*math.sin(a),z),(.018,.075,.055+(i%3)*.018),MARK))
    forks=[((0,0,3.1),(-1.55,.12,4.9)),((0,0,3.8),(1.45,-.18,5.55)),((0,0,4.6),(-.92,-.2,6.25)),((0,0,5.0),(.88,.18,6.65))]
    for i,(a,b) in enumerate(forks):
        parts.append(limb("BirchBranch",a,b,.13-i*.012,BIRCH))
        parts.append(ico("BirchCrown",b,(1.22,1.08,.92),OLIVE if i%2 else NEEDLE))
    parts.append(ico("BirchCrownTop",(0,0,7.05),(1.15,1.02,.88),OLIVE))
    return join("birchTrees",parts)

def shrub(name, dead=False):
    foliage=BARK if dead else OLIVE; parts=[]
    for i in range(5):
        a=i*math.tau/5+.2; start=(0,0,-.32); end=(.42*math.cos(a),.42*math.sin(a),-.03+(i%2)*.12)
        parts.append(limb("ShrubTwig",start,end,.065,BARK))
        parts.append(ico("ShrubCluster",end,(.42,.36,.3),foliage))
    return join(name,parts)

def grass():
    parts=[]
    for i in range(7):
        a=i*math.tau/7; base=(.05*math.cos(a),.05*math.sin(a),-.23); tip=(.38*math.cos(a),.38*math.sin(a),.28+(i%3)*.08)
        parts.append(limb("GrassBlade",base,tip,.028,OLIVE))
    return join("grassTufts",parts)

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
os.makedirs(OUT,exist_ok=True); OBJ_PALETTE=palette_texture()
spruce(); birch()
cone("treeTrunks",(0,0,0),2.28,.30,.16,BARK,7)
ico("treeCrowns",(0,0,0),(1.22,1.22,1.05),OLIVE); ico("treeCrownsAlt",(0,0,0),(1.12,1.12,.96),NEEDLE)
branch=limb("treeBranches",(0,0,-.85),(.78,0,.85),.12,BARK)
shrub("scrubInstances"); shrub("deadBrushInstances",True); grass()
petals=[ico("FlowerPetal",(.13*math.cos(i*math.tau/5),.13*math.sin(i*math.tau/5),-.18),(.11,.11,.12),RUST) for i in range(5)]
join("flowerInstances",petals)
# Library-only reference forms for future landmarks; generated monuments retain semantic parts.
ico("LibraryRock",(5,0,0),(1.4,1.1,1.0),STONE); cube("LibraryCheckpoint",(-5,0,1.1),(1.8,1.5,.18),IRON)
for item in [node for node in bpy.context.scene.objects if node.type=='MESH']:
    bake(item); collapse_palette(item); item["style"]="military_lowpoly"; item["runtime_pool"]=item.name
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,"assets","environment","military_environment.glb"),export_format='GLB',export_yup=True,use_selection=True)
use_obj_palette(OBJ_PALETTE)
models=[item for item in bpy.context.scene.objects if item.type=='MESH']
for item in models:
    bpy.ops.object.select_all(action='DESELECT'); item.select_set(True)
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT,item.name+'.obj'),export_selected_objects=True,export_materials=True,export_triangulated_mesh=True,forward_axis='NEGATIVE_Z',up_axis='Y')
for index,item in enumerate(models): item.location=((index%4)*8,(index//4)*10,0)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"military_environment.blend"),check_existing=False)
bpy.ops.wm.obj_export(filepath=os.path.join(OUT,"military_environment.obj"),export_materials=True,export_triangulated_mesh=True,forward_axis='NEGATIVE_Z',up_axis='Y')
