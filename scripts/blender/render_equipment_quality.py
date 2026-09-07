"""Reproducible Blender studio sheets for equipment and trailers."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import build_player
OUT = ROOT/'docs/validation/model-quality'
OUT.mkdir(parents=True, exist_ok=True)


def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def render(name, width, target, location):
    scene=bpy.context.scene
    camera=build_player.add_stage(scene)
    scene.world.color=(.35,.35,.35)
    bpy.ops.object.light_add(type='SUN', location=(0,0,15))
    bpy.context.object.data.energy=1.1
    bpy.context.object.rotation_euler=(.45,-.35,-.35)
    camera.data.ortho_scale=width
    build_player.look_at(camera,location,target)
    scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=1600
    scene.render.resolution_y=1100
    scene.render.resolution_percentage=100
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)


reset()
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/models/equipment/equipment.blend'))
render('equipment-blender',27,(7.2,6.8,.5),(19,-15,25))
reset()
for index,kind in enumerate(('cargo','repair','weapon','fuel','anti_tank','anti_air')):
    bpy.ops.import_scene.gltf(filepath=str(ROOT/f'assets/vehicles/military_wagon_{kind}.glb'))
    for obj in list(bpy.context.selected_objects):
        if obj.parent is None:
            obj.location=(index%3*7,index//3*9,0)
render('wagons-blender',24,(7,4.5,1.5),(25,-26,26))

reset()
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/actors/military_field_props.glb'))
for obj in list(bpy.context.scene.objects):
    ancestor=obj
    while ancestor.parent:
        ancestor=ancestor.parent
    if ancestor.name != 'FIELD_heal_cart':
        bpy.data.objects.remove(obj, do_unlink=True)
render('heal-cart-blender',6,(0,0,1.1),(6,-9,5))

reset()
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/actors/military_field_props.glb'))
allowed = ('FIELD_pickup_fuel','FIELD_pickup_salvage','FIELD_mine_enemy')
for obj in list(bpy.context.scene.objects):
    ancestor=obj
    while ancestor.parent:
        ancestor=ancestor.parent
    if ancestor.name not in allowed:
        bpy.data.objects.remove(obj, do_unlink=True)
for index, name in enumerate(allowed):
    bpy.data.objects[name].location=(index*1.8,0,0)
render('small-props-blender',6.5,(1.8,0,.45),(6,-9,6))
