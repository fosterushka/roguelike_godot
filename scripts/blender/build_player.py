"""Build, export and preview the authored pickup geometry."""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/player"
GAME_OUT = ROOT / "assets/vehicles/military_pickup.glb"
sys.path.insert(0, str(Path(__file__).parent))
from pickup_geometry import PALETTE, create_meshes


def palette_material():
    image = bpy.data.images.new("palette.png", 32, 32)
    colors = [tuple(int(color[index:index + 2], 16) / 255 for index in (0, 2, 4)) + (1,)
              for color in PALETTE.values()]
    for index, color in enumerate(colors):
        row, column = divmod(index, 4)
        for y in range(row * 8, row * 8 + 8):
            for x in range(column * 8, column * 8 + 8):
                image.pixels[(y * 32 + x) * 4:(y * 32 + x + 1) * 4] = color
    image.filepath_raw = str(OUT / "palette.png")
    image.file_format = "PNG"
    image.save()
    image.pack()
    image.filepath = "//palette.png"
    material = bpy.data.materials.new("Pickup_Palette")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .82
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Closest"
    material.node_tree.links.new(texture.outputs["Color"], material.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return material


def add_stage(scene):
    stage = bpy.data.collections.new("PRESENTATION_ONLY")
    scene.collection.children.link(stage)
    for location, energy in (((4, -6, 7), 1250), ((-4, -1, 5), 900), ((2, 5, 6), 1200)):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        for collection in list(light.users_collection): collection.objects.unlink(light)
        stage.objects.link(light)
        light.data.energy, light.data.shape, light.data.size = energy, "DISK", 5
        light.rotation_euler = (Vector((0, 0, 1.2)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(8, -12, 7))
    camera = bpy.context.object
    for collection in list(camera.users_collection): collection.objects.unlink(camera)
    stage.objects.link(camera)
    camera.data.type, camera.data.ortho_scale = "ORTHO", 8.7
    scene.camera = camera
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.025))
    floor = bpy.context.object
    floor.name = "PreviewGround"
    for collection in list(floor.users_collection):
        collection.objects.unlink(floor)
    stage.objects.link(floor)
    ground = bpy.data.materials.new("PreviewGround")
    ground.use_nodes = True
    ground.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.12, .14, .15, 1)
    ground.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .95
    floor.data.materials.append(ground)
    return camera


def look_at(camera, location, target):
    camera.location = location
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections): bpy.data.collections.remove(collection)
    scene = bpy.context.scene
    scene["asset_origin"] = "authored_from_scratch"
    scene["asset_type"] = "pickup"
    scene["asset_style"] = "military_utility_pickup"
    model = bpy.data.collections.new("MODEL")
    scene.collection.children.link(model)
    material = palette_material()
    result = create_meshes(material)
    body = bpy.data.objects.new("PICKUP_BODY", result["body"])
    model.objects.link(body)
    for wheel in result["wheel_centers"]:
        pivot = bpy.data.objects.new("PIVOT_WHEEL_" + wheel["name"], None)
        pivot.location = wheel["center"]
        model.objects.link(pivot)
        mesh = bpy.data.objects.new("WHEEL_" + wheel["name"], result["wheel"])
        mesh.parent = pivot
        mesh.matrix_parent_inverse = Matrix.Identity(4)
        model.objects.link(mesh)
    camera = add_stage(scene)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.11, .13, .15, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .45
    look_at(camera, (8, -12, 7), (0, 0, 1.15))
    scene.render.filepath = str(OUT / "preview.png")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.shading.type = "MATERIAL"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "player.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in model.objects:
        if obj.type == "MESH": obj.select_set(True)
    bpy.ops.wm.obj_export(filepath=str(OUT / "player.obj"), export_selected_objects=True,
        export_materials=True, export_uv=True, export_normals=True, export_triangulated_mesh=True,
        forward_axis="NEGATIVE_Z", up_axis="Y")
    # GLB carries the palette image internally and keeps the four editable
    # PIVOT_WHEEL_* nodes. Presentation-only camera/lights are not selected.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in model.objects:
        obj.select_set(True)
    GAME_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(GAME_OUT), export_format="GLB",
        use_selection=True, export_materials="EXPORT", export_image_format="AUTO",
        export_keep_originals=True, export_yup=True)
    look_at(camera, (8, -12, 7), (0, 0, 1.15))
    scene.render.filepath = str(OUT / "preview.png")
    bpy.ops.render.render(write_still=True)
    look_at(camera, (-8, 12, 7), (0, .15, 1.15))
    scene.render.filepath = str(OUT / "preview_rear.png")
    bpy.ops.render.render(write_still=True)
    meshes = [obj for obj in model.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    stats = {"origin": "authored_from_scratch", "source": "no external mesh", "style": "military_utility_pickup",
        "output": {"objects": len(meshes), "unique_meshes": len({obj.data.name for obj in meshes}),
        "vertices": sum(len(obj.data.vertices) for obj in meshes),
        "triangles": sum(len(poly.vertices) - 2 for obj in meshes for poly in obj.data.polygons),
        "materials": 1, "wheel_count": 4}, "palette_pixels": [32, 32],
        "dimensions_blender_xyz": [round(max(p[i] for p in points) - min(p[i] for p in points), 4) for i in range(3)],
        "wheel_centers": [wheel["center"] for wheel in result["wheel_centers"]]}
    (OUT / "stats.json").write_text(json.dumps(stats, indent=2) + "\n")


if __name__ == "__main__": main()
