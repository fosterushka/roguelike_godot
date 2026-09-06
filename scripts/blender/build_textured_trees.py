"""Straight trees with the pre-migration proportions and quiet solid-color shading."""
from pathlib import Path
import bpy, shutil, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/trees_rebuilt'; GAME=ROOT/'assets/environment'
SIZE=32; TILE=16

def atlas():
    # Four quiet color ramps, without bark marks, leaf shapes or grain.
    pixels=[0.0]*(SIZE*SIZE*4)
    colors=['80654c','d6d2bd','649274','91a36c']
    for tile,hex_color in enumerate(colors):
        base=[int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
        for y in range(TILE):
            shade=(y/(TILE-1)-.5)*(.12 if tile>=2 else .035)
            rgb=[max(0,min(1,c+shade)) for c in base]
            linear=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
            for x in range(TILE):
                index=(((tile//2)*TILE+y)*SIZE+(tile%2)*TILE+x)*4
                pixels[index:index+4]=[*linear,1]
    image=bpy.data.images.new('tree_bark_and_foliage',width=SIZE,height=SIZE,alpha=True)
    image.pixels.foreach_set(pixels);image.filepath_raw=str(OUT/'tree_atlas.png');image.file_format='PNG';image.save()
    shutil.copyfile(OUT/'tree_atlas.png',GAME/'tree_atlas.png')
    mat=bpy.data.materials.new('TexturedTrees');mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.95
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    return mat

def finish(obj,tile,mat):
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='TreeUV')
    uv.name='TreeUV'
    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex=obj.data.vertices[obj.data.loops[loop_index].vertex_index]
            height=max(0,min(1,(obj.location.z+vertex.co.z*obj.scale.z)/9.4))
            uv.data[loop_index].uv=((tile%2+.5)/2,(tile//2+.08+height*.84)/2)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:face.use_smooth=len(face.vertices)<=4
    return obj

def stem(at,height,bottom,top,tile,mat):
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=bottom,radius2=top,depth=height,location=at)
    return finish(bpy.context.object,tile,mat)

def branch(a,b,r,tile,mat):
    a,b=Vector(a),Vector(b);obj=stem((a+b)/2,(b-a).length,r,r*.5,tile,mat)
    obj.rotation_mode='QUATERNION';obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(b-a)
    return obj

def crown(at,scale,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=at)
    obj=bpy.context.object;obj.scale=scale
    return finish(obj,3,mat)

def build(name,mat):
    if name=='spruceTrees':
        pieces=[stem((0,0,1.8),3.6,.28,.16,0,mat)]
        for tier in range(4):
            pieces.append(stem((0,0,3.65+tier*1.48),3.3-tier*.24,3.0-tier*.64,0,2,mat))
    else:
        pieces=[stem((0,0,3.1),6.2,.24,.12,1,mat)]
        pieces += [branch((0,0,3.3),(-1.3,-.2,5.5),.12,1,mat),branch((0,0,4.1),(1.25,.35,6),.10,1,mat)]
        for at,scale in [((-1.25,0,5.75),(1.55,1.3,1.75)),((1.15,.3,6.4),(1.65,1.35,1.65)),((.1,-.15,7.3),(1.65,1.4,1.7))]:pieces.append(crown(at,scale,mat))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:obj.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0];bpy.ops.object.join();obj=pieces[0];obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    return obj

def main():
    OUT.mkdir(parents=True,exist_ok=True);GAME.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    mat=atlas();models=[build(n,mat) for n in ['spruceTrees','birchTrees']]
    for obj in models:
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
        bpy.ops.wm.obj_export(filepath=str(OUT/(obj.name+'.obj')),export_selected_objects=True,export_materials=True,forward_axis='NEGATIVE_Z',up_axis='Y')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(GAME/'textured_trees.glb'),export_format='GLB',use_selection=True)
    for i,obj in enumerate(models):obj.location.x=i*8
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'textured_trees.blend'))
if __name__=='__main__':main()
