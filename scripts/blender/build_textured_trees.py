"""Authored branch silhouettes and clustered crowns with a shared quiet atlas."""
from pathlib import Path
import bpy, shutil, bmesh, math, random, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/trees_rebuilt'; GAME=ROOT/'assets/environment'
SIZE=32; TILE=16

def atlas():
    # Four quiet color ramps, without bark marks, leaf shapes or grain.
    pixels=[0.0]*(SIZE*SIZE*4)
    colors=['705742','d6d2bd','42674b','819750']
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

def stem(at,height,bottom,top,tile,mat,vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=bottom,radius2=top,depth=height,location=at)
    return finish(bpy.context.object,tile,mat)

def branch(a,b,r,tile,mat,top_ratio=.35,vertices=6):
    a,b=Vector(a),Vector(b);obj=stem((a+b)/2,(b-a).length,r,r*top_ratio,tile,mat,vertices)
    obj.rotation_mode='QUATERNION';obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(b-a)
    return obj

TREE_TRIANGLE_BUDGET = 4000
TREE_SEED = 72841
SPRUCE_TIERS = 7
SPRUCE_ARMS = 6
BIRCH_ARMS = 9
TREE_NAMES = ('spruceTrees', 'birchTrees')


class Foliage:
    """All leaf sprays share one mesh and one atlas surface, without alpha overdraw."""
    def __init__(self):
        self.vertices, self.faces = [], []

    def leaf(self, center, direction, length, width, seed, needle=False):
        rng = random.Random(seed)
        center, axis = Vector(center), Vector(direction).normalized()
        lateral = axis.cross(Vector((0,0,1)))
        if lateral.length < .01: lateral = Vector((1,0,0))
        lateral.normalize()
        normal = lateral.cross(axis).normalized()
        # Paired serrated edges and a raised central vein make a closed, thin volume.
        outline = [(0,0),(.24,-.62),(.45,-1),(1,0),(.45,1),(.24,.62)] if needle else [
                   (0,0),(.45,-1),(1,0),(.45,1)]
        offset = len(self.vertices)
        for along, across in outline:
            p = center + axis*(along*length) + lateral*(across*width*(.9+rng.random()*.15))
            self.vertices.append(tuple(p))
        for side in [-1,1]:
            self.vertices.append(tuple(center + axis*(length*.44) + normal*(side*width*(.45 if needle else .13))))
        count=len(outline)
        for i in range(count):
            nxt=(i+1)%count
            self.faces += [(offset+i,offset+nxt,offset+count),
                           (offset+nxt,offset+i,offset+count+1)]

    def object(self, name, tile, mat):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(self.vertices,[],self.faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        finish(obj,tile,mat)
        for polygon in mesh.polygons: polygon.use_smooth=False
        return obj


def build(name,mat,distant=False):
    rng=random.Random(TREE_SEED)
    pieces=[]; foliage=Foliage()
    spruce=name==TREE_NAMES[0]
    tile=0 if spruce else 1
    # A tapering segmented trunk and visible roots provide a grounded silhouette.
    height=9.15 if spruce else 7.8
    trunk=[]
    for i in range(7):
        t=i/6
        trunk.append(Vector((math.sin(t*2.4)*(.10 if spruce else .25), math.sin(t*3.4)*.09,height*t)))
    for i in range(6):
        pieces.append(branch(trunk[i],trunk[i+1],.30*(1-i/7),tile,mat,(6-i)/(7-i)))
    for i in range(5):
        angle=i*math.tau/5+.3
        pieces.append(branch((0,0,.45),(math.cos(angle)*.67,math.sin(angle)*.67,.035),.14,tile,mat))
    if spruce:
        tiers = 5 if distant else SPRUCE_TIERS
        arm_count = 4 if distant else SPRUCE_ARMS
        for tier_index in range(tiers):
            tier = tier_index * (SPRUCE_TIERS - 1) / (tiers - 1)
            h=1.8+tier*.95
            spread=2.45*(1-tier/10.5)
            arms=arm_count if tier<6 else arm_count-2
            for arm in range(arms):
                angle=arm*math.tau/arms+tier*1.17+rng.uniform(-.12,.12)
                radial=Vector((math.cos(angle),math.sin(angle),0))
                across=Vector((-radial.y,radial.x,0))
                start=Vector((.08,0,h+.20))
                tip=start+radial*spread+Vector((0,0,-.26+rng.uniform(-.1,.1)))
                pieces.append(branch(start,tip,.065*(1-tier*.065),0,mat,vertices=4))
                for twig in range(2 if distant else 3):
                    f=.18+twig*(.60 if distant else .30)
                    origin=start.lerp(tip,f)
                    for side in [-1,1]:
                        reach=(.66-twig*.085)*(1-tier*.055)
                        end=origin+radial*(reach*.32)+across*(side*reach)+Vector((0,0,-reach*.17))
                        for needle in range(1):
                            at=origin.lerp(end,.14+needle*.43)
                            direction=radial*.60+across*(side*(.48+needle*.14))+Vector((0,0,-.26-twig*.07))
                            foliage.leaf(at,direction,(1.05-twig*.08)*(1-tier*.045),(.48 if distant else .36)*(1-tier*.045),tier*1000+arm*100+twig*10+needle,True)
        # Open leader with small ascending needle shoots, instead of a top cone.
        for i in range(12):
            a=i*2.399;z=8.15+i*.075
            foliage.leaf((.09,0,z),(math.cos(a)*.45,math.sin(a)*.45,1),.42,.065,9000+i,True)
    else:
        for arm in range(BIRCH_ARMS):
            angle=arm*2.399
            radial=Vector((math.cos(angle),math.sin(angle),0))
            across=Vector((-radial.y,radial.x,0))
            start=Vector((.12,0,2.8+arm*.36))
            extent=2.2-arm*.09
            end=start+radial*extent+Vector((0,0,1.55+arm*.04))
            pieces.append(branch(start,end,.105-arm*.007,1,mat))
            for twig in range(4):
                side=-1 if twig%2 else 1
                fork=end-radial*(twig*.27)+across*(side*(.40+twig*.08))+Vector((0,0,.4+twig*.08))
                attach=start.lerp(end,.55+twig*.08)
                pieces.append(branch(attach,fork,.033,1,mat))
                for leaf in range(8):
                    a=leaf*2.399+arm
                    radius=.14+(leaf%4)*.14
                    at=fork+Vector((math.cos(a)*radius,math.sin(a)*radius,rng.uniform(-.30,.38)))
                    direction=Vector((math.cos(a),math.sin(a),rng.uniform(-.5,1.1)))
                    foliage.leaf(at,direction,.65+rng.random()*.17,.30+rng.random()*.06,arm*1000+twig*30+leaf)
        for index in range(25):
            angle=index*2.399;z=.35+index*.20
            radius=.295*(1-z/10)
            bpy.ops.mesh.primitive_cube_add(size=1,location=(math.cos(angle)*radius,math.sin(angle)*radius,z))
            obj=bpy.context.object;obj.scale=(.14+index%3*.03,.012,.023);obj.rotation_euler.z=angle+math.pi/2
            pieces.append(finish(obj,0,mat))
    pieces.append(foliage.object('Needle branches' if spruce else 'Individual birch leaves',2 if spruce else 3,mat))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:obj.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0];bpy.ops.object.join();obj=pieces[0];obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    minimum_z=min(vertex.co.z for vertex in obj.data.vertices)
    for vertex in obj.data.vertices: vertex.co.z-=minimum_z
    return obj

def main():
    OUT.mkdir(parents=True,exist_ok=True);GAME.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    for obj in list(bpy.context.scene.objects): bpy.data.objects.remove(obj,do_unlink=True)
    mat=atlas();models=[build(n,mat) for n in TREE_NAMES]
    distant=build(TREE_NAMES[0],mat,True);distant.name="spruceTreesDistant";models.append(distant)
    for obj in models:
        assert len(obj.data.polygons) <= TREE_TRIANGLE_BUDGET, obj.name + ' exceeds tree triangle budget'
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
        bpy.ops.wm.obj_export(filepath=str(OUT/(obj.name+'.obj')),export_selected_objects=True,export_materials=True,forward_axis='NEGATIVE_Z',up_axis='Y')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(GAME/'textured_trees.glb'),export_format='GLB',use_selection=True)
    stats={obj.name:{'triangles':len(obj.data.polygons),'surfaces':len(obj.data.materials)} for obj in models}
    (OUT/'stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    print('TREE_REVISION',stats)
    for i,obj in enumerate(models):obj.location.x=i*8
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'textured_trees.blend'))
if __name__=='__main__':main()
