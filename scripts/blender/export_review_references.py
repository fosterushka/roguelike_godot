"""Export actual Blender tree/player mesh buffers for the offline review page."""
from pathlib import Path
import bpy,json,importlib.util
ROOT=Path(__file__).resolve().parents[2]

def run():
    old=bpy.context.window.scene
    scene=bpy.data.scenes.new('Review references');bpy.context.window.scene=scene
    result={}
    try:
        for key,path in [('player','assets/vehicles/military_pickup.glb'),('trees','assets/environment/textured_trees.glb')]:
            for obj in list(scene.objects):bpy.data.objects.remove(obj,do_unlink=True)
            bpy.ops.import_scene.gltf(filepath=str(ROOT/path))
            groups={key:[o for o in scene.objects if o.type=='MESH']} if key=='player' else {o.name:[o] for o in scene.objects if o.type=='MESH'}
            for name,objects in groups.items():
                data={'positions':[],'normals':[],'colors':[],'solidColors':[],'parts':len(objects)}
                for obj in objects:
                    obj.data.calc_loop_triangles()
                    texture=next(n.image for n in obj.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
                    width,height=texture.size;pixels=list(texture.pixels)
                    matrix=obj.matrix_world;nm=matrix.to_3x3().inverted().transposed()
                    for tri in obj.data.loop_triangles:
                        for li in tri.loops:
                            loop=obj.data.loops[li];v=matrix@obj.data.vertices[loop.vertex_index].co
                            # Use authored loop normals for the softly shaded crowns.
                            n=(nm@obj.data.corner_normals[li].vector).normalized()
                            uv=obj.data.uv_layers.active.data[li].uv
                            x=min(width-1,int(uv.x*width));y=min(height-1,int(uv.y*height))
                            color=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in pixels[(y*width+x)*4:(y*width+x)*4+3]]
                            solid=color
                            if key=='trees':
                                tile=int(uv.x*2)+int(uv.y*2)*2
                                h=('705742','d6d2bd','42674b','819750')[tile]
                                srgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
                                solid=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in srgb]
                            for field,values in [('positions',v),('normals',n),('colors',color),('solidColors',solid)]:data[field].extend(round(c,5) for c in values)
                data['triangles']=len(data['positions'])//9;result[name]=data
        (ROOT/'docs/enemy-vehicle-review/references.js').write_text('window.REFERENCE_DATA='+json.dumps(result,separators=(',',':'))+';\n')
        print('REVIEW_REFERENCES',[(k,v['triangles']) for k,v in result.items()])
    finally:
        bpy.context.window.scene=old
        for obj in list(scene.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.scenes.remove(scene)

if __name__=='__main__':run()
