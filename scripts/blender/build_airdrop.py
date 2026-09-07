"""Ribbed military supply case with webbing, latches and two red signal flares."""
import sys
from pathlib import Path
import bpy
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import build_player
import build_world_assets
from build_equipment import box, tube, beam
from pickup_geometry import MeshBuilder
OUT = ROOT / 'assets/models/airdrop'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    build_player.OUT = OUT
    material = build_player.palette_material()
    body = MeshBuilder()
    box(body,(0,1.26,0),(2.70,2.20,2.45),'paint')
    box(body,(0,2.42,0),(2.80,.19,2.55),'paint_light')
    for y in [.22,.75,1.29,1.84,2.34]:
        for z in [-1.24,1.24]: box(body,(0,y,z),(2.76,.045,.065),'paint_shadow')
        for x in [-1.37,1.37]: box(body,(x,y,0),(.065,.045,2.5),'paint_shadow')
    for x in [-.84,.84]:
        for z in [-1.26,1.26]:
            box(body,(x,1.32,z),(.13,2.27,.055),'trim')
            box(body,(x,1.98,z*1.025),(.21,.30,.07),'steel')
            box(body,(x,2.0,z*1.06),(.085,.15,.035),'dark')
        box(body,(x,2.54,0),(.13,.05,2.61),'trim')
    for x in [-1.34,1.34]:
        for z in [-1.2,1.2]: box(body,(x,1.30,z),(.13,2.33,.15),'steel')
        for z in [-.27,.27]: box(body,(x*1.055,1.77,z),(.065,.15,.08),'steel')
        beam(body,(x*1.07,1.77,-.27),(x*1.07,1.77,.27),.045,'trim')
    box(body,(0,1.85,1.30),(.65,.28,.04),'paint_light')
    for x in [-.20,0,.20]: box(body,(x,1.85,1.325),(.055,.14,.01),'paint_shadow')
    for x in [-.60,.60]: box(body,(x,.10,0),(.25,.20,2.45),'trim')
    for x,z in [(.62,.58),(-.65,-.55)]:
        tube(body,(x,2.67,z),.085,.32,'red',segments=10)
        tube(body,(x,2.86,z),.078,.06,'lamp',segments=10)
    parts=[('Body',body,(0,0,0))]+build_world_assets.build('airdrop')[1:]
    root=bpy.data.objects.new('FIELD_airdrop',None);bpy.context.collection.objects.link(root)
    for name,builder,at in parts:
        obj=bpy.data.objects.new(name,builder.finish(name,material));bpy.context.collection.objects.link(obj)
        obj.parent=root;obj.location=(at[0],-at[2],at[1])
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'airdrop.blend'))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/actors/airdrop.glb'),export_format='GLB',use_selection=True,export_yup=True)
if __name__=='__main__': main()
