"""Deterministic Blender evidence sheet; run after opening the authored blend."""
import bpy, math, os
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
MODELS = ('buggy','raider','repairCrawler','boss','wreck_bike','wreck_buggy','wreck_jammerTruck','wreck_repairCrawler','wreck_minelayer')
def render(label):
    models = [bpy.data.objects[name] for name in MODELS]
    for obj in bpy.data.objects:
        if obj.type == 'MESH': obj.hide_render = obj.parent not in models
    for index, model in enumerate(models):
        model.location = (0,0,0)
        bpy.context.view_layer.update()
        points = [child.matrix_world @ Vector(v) for child in model.children for v in child.bound_box]
        low=Vector(tuple(min(p[a] for p in points) for a in range(3)))
        high=Vector(tuple(max(p[a] for p in points) for a in range(3)))
        scale = 5.7 / max(high.x-low.x,high.y-low.y,high.z-low.z)
        model.scale = (scale,)*3
        model.location = ((index%3)*8-(low.x+high.x)*scale/2, (index//3)*8-(low.y+high.y)*scale/2, -low.z*scale)
        bpy.ops.object.text_add(location=((index%3)*8-2.8,(index//3)*8-3.6,.02))
        text=bpy.context.object;text.data.body=MODELS[index];text.data.size=.48;text.data.extrude=.001
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.03))
    mat=bpy.data.materials.new('ReviewGround');mat.diffuse_color=(.12,.15,.17,1);bpy.context.object.data.materials.append(mat)
    scene=bpy.context.scene
    world=bpy.data.worlds.new('ReviewWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.40,.48,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.world=world
    for loc,power,size in [((-10,-12,24),2600,16),((20,10,20),2100,14)]:
        bpy.ops.object.light_add(type='AREA',location=loc);bpy.context.object.data.energy=power;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=size
    bpy.ops.object.camera_add(location=(25,-30,43));camera=bpy.context.object;camera.rotation_euler=(Vector((8,8,0))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=32;scene.camera=camera
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1600;scene.render.resolution_y=1600;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.filepath=os.path.join(ROOT,'docs/validation/model-rebuild/vehicles-'+label+'.png')
    bpy.ops.render.render(write_still=True)
