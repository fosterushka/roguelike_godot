"""Build the authored low-poly infantry library used by the Godot soldier rig.

The source geometry is deliberately small: each person is seven articulated
pieces, with shared limbs and a shared palette material.  Z is up in Blender;
Godot receives the same axis convention through the GLB exporter.
"""
from pathlib import Path
import sys
import math

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/people"
GAME_OUT = ROOT / "assets/actors/military_people.glb"
sys.path.insert(0, str(Path(__file__).parent))
from pickup_geometry import MeshBuilder, PALETTE


RIG = {
    "BODY": ("body", None, (0.0, 1.08, 0.0), (0.0, 0.0, 0.0)),
    "HEAD": ("head", None, (0.0, 1.68, 0.015), (0.0, 0.0, 0.0)),
    "LEG_L": ("leg", -1.0, (-0.17, 0.74, 0.0), (0.0, 0.0, 0.0)),
    "LEG_R": ("leg", 1.0, (0.17, 0.74, 0.0), (0.0, 0.0, 0.0)),
    "ARM_L": ("arm", -1.0, (-0.39, 1.4, 0.0), (0.0, 0.0, -0.10)),
    "ARM_R": ("arm", 1.0, (0.39, 1.4, 0.0), (0.0, 0.0, 0.10)),
    "WEAPON": ("weapon", 1.0, (-0.46, 1.23, 0.24), (0.0, 0.0, -0.08)),
}


def palette_material():
    image = bpy.data.images.new("people_palette.png", 32, 32)
    for index, hex_color in enumerate(PALETTE.values()):
        color = tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)
        row, column = divmod(index, 4)
        for y in range(row * 8, row * 8 + 8):
            for x in range(column * 8, column * 8 + 8):
                image.pixels[(y * 32 + x) * 4:(y * 32 + x + 1) * 4] = color
    image.filepath_raw = str(OUT / "palette.png")
    image.file_format = "PNG"
    image.save()
    image.pack()
    image.filepath = "//palette.png"
    material = bpy.data.materials.new("MilitaryPeoplePalette")
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.88
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Closest"
    material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def mesh(name, build, material):
    builder = MeshBuilder()
    build(builder)
    # MeshBuilder's authored coordinates follow Godot (Y-up) so they can be
    # checked beside the combat rig.  Blender is Z-up; convert once at export.
    builder.vertices = [(x, -z, y) for x, y, z in builder.vertices]
    return builder.finish(name, material)


def limb_meshes(material):
    def leg(builder):
        builder.box((0, -0.23, 0.0), (.18, .47, .19), "paint_shadow")
        builder.box((0, -0.25, .112), (.19, .16, .055), "trim")
        builder.box((0, -0.47, .035), (.22, .16, .31), "rubber")
        builder.box((0, -0.555, .018), (.235, .045, .34), "dark")
        builder.box((0, -0.025, .0), (.205, .08, .205), "paint_light")
    def arm(builder):
        builder.box((0, -0.22, 0.0), (.16, .45, .16), "paint")
        builder.box((0, -0.12, .095), (.175, .15, .035), "paint_light")
        builder.box((0, -0.47, .0), (.135, .12, .135), "accent")
        builder.box((0, -0.03, .0), (.19, .07, .19), "paint_light")
    def head(builder):
        builder.box((0, 0.0, 0.0), (.34, .34, .34), "accent")
        builder.box((0, -.035, .182), (.25, .10, .026), "glass")
        for side in (-1, 1):
            builder.box((side * .075, -.035, .202), (.10, .075, .022), "glass_light")
        builder.box((0, -.035, .195), (.035, .09, .032), "trim")
        builder.box((0, -.18, -.02), (.13, .05, .13), "accent")
        rings = []
        for y, radius in ((.09, .215), (.23, .205), (.29, .14)):
            rings.append([(math.cos(index * math.tau / 8) * radius, y, math.sin(index * math.tau / 8) * radius) for index in range(8)])
        builder.loft(rings, "paint", "paint_light")
        builder.box((0, .09, .20), (.38, .065, .075), "paint_shadow")
    return mesh("MilitarySharedLeg", leg, material), mesh("MilitarySharedArm", arm, material), mesh("MilitarySharedHead", head, material)


def torso_mesh(kind, material):
    def build(builder):
        color = "paint" if kind in ("rifleman", "ak", "bazooka") else "paint_shadow"
        builder.box((0, 0.0, 0.0), (.54, .70, .32), color)
        builder.box((0, -.19, .19), (.48, .40, .075), "trim")
        builder.box((0, -.42, .02), (.58, .06, .34), "paint_light")
        builder.box((0, .24, -.20), (.44, .22, .10), "bed")
        builder.box((0, -.24, .245), (.43, .07, .045), "paint_light")
        for side in (-1, 0, 1):
            builder.box((side * .14, -.06, .245), (.115, .16, .055), "bed")
        builder.box((-.31, .06, .08), (.11, .28, .17), "steel")
        builder.box((-.31, .19, .19), (.12, .045, .06), "accent")
        for side in (-1, 1):
            builder.box((side * .32, .20, .0), (.12, .24, .24), "paint_light")
        if kind == "ak":
            builder.box((0, -.41, .22), (.34, .12, .05), "accent")
            builder.box((.31, .08, .01), (.11, .42, .16), "steel")
        elif kind == "bazooka":
            builder.box((0, .30, .20), (.42, .18, .10), "steel")
            builder.box((-.31, .0, .05), (.09, .48, .17), "trim")
        elif kind == "bomber":
            builder.box((0, -.42, .22), (.43, .08, .10), "red")
            for side in (-1, 1): builder.box((side * .19, -.46, .22), (.08, .08, .12), "amber")
        else:
            builder.box((0, -.40, .22), (.40, .09, .06), "paint_light")
    return mesh("Military%sBody" % kind.capitalize(), build, material)


def weapon_mesh(kind, material):
    def rifle(builder):
        builder.box((0, -.28, .03), (.10, .78, .10), "trim")
        builder.box((0, -.03, .03), (.18, .22, .15), "steel")
        builder.box((0, -.63, .03), (.052, .28, .052), "dark")
        builder.box((0, -.48, .03), (.12, .045, .13), "paint_light")
        builder.box((0, -.12, -.09), (.09, .25, .12), "bed")
        builder.box((0, -.38, .105), (.035, .17, .035), "accent")
        builder.box((0, .10, -.08), (.08, .25, .18), "bed")
    def ak(builder):
        rifle(builder)
        builder.box((0, -.45, .03), (.13, .28, .11), "paint_light")
        builder.box((0, .10, -.08), (.12, .28, .18), "accent")
    def bazooka(builder):
        rings = []
        for y, radius in ((-.55, .145), (.33, .145)):
            rings.append([(math.cos(index * math.tau / 10) * radius, y, math.sin(index * math.tau / 10) * radius) for index in range(10)])
        builder.loft(rings, "steel", "trim")
        builder.box((0, -.08, -.16), (.18, .23, .12), "paint")
        builder.box((0, .30, .0), (.29, .09, .29), "trim")
        builder.box((0, -.52, .0), (.32, .07, .32), "dark")
    def bomb(builder):
        builder.box((0, -.08, .0), (.42, .34, .25), "red")
        builder.box((0, -.08, .16), (.11, .12, .10), "amber")
        builder.box((0, .15, .0), (.10, .15, .10), "trim")
    funcs = {"rifleman": rifle, "ak": ak, "bazooka": bazooka, "bomber": bomb}
    return mesh("Military%sWeapon" % kind.capitalize(), funcs[kind], material)


def add_part(parent, object_name, part_mesh, key, kind, weapon_position=None):
    role, side, position, rotation = RIG[key]
    if key == "WEAPON" and kind == "bomber":
        position = (0.0, 1.13, 0.30)
    obj = bpy.data.objects.new(object_name, part_mesh)
    parent.users_collection[0].objects.link(obj)
    obj.parent = parent
    # The same fixed basis change makes the standalone GLB stand upright while
    # its exported local mesh remains identical to the Godot rig coordinates.
    axis = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    obj.location = (position[0], -position[2], position[1])
    obj.rotation_euler = (axis @ Euler(rotation).to_matrix() @ axis.inverted()).to_euler()
    obj["rig_role"] = role
    obj["rig_kind"] = kind
    if side is not None: obj["rig_side"] = side
    return obj


def add_model(collection, kind, shared, material):
    root = bpy.data.objects.new("MODEL_" + kind.upper(), None)
    collection.objects.link(root)
    body = torso_mesh(kind, material)
    weapon = weapon_mesh(kind, material)
    parts = {"BODY": body, "HEAD": shared[2], "LEG_L": shared[0], "LEG_R": shared[0], "ARM_L": shared[1], "ARM_R": shared[1], "WEAPON": weapon}
    for key, part_mesh in parts.items():
        add_part(root, "%s_%s" % (kind.upper(), key), part_mesh, key, kind)
    return root


def add_preview(scene):
    stage = bpy.data.collections.new("PRESENTATION_ONLY")
    scene.collection.children.link(stage)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.object
    for owner in list(floor.users_collection): owner.objects.unlink(floor)
    stage.objects.link(floor)
    floor_mat = bpy.data.materials.new("PreviewGround")
    floor_mat.diffuse_color = (.07, .09, .08, 1)
    floor.data.materials.append(floor_mat)
    bpy.ops.object.light_add(type="AREA", location=(4, -6, 7))
    light = bpy.context.object
    for owner in list(light.users_collection): owner.objects.unlink(light)
    stage.objects.link(light)
    light.data.energy, light.data.shape, light.data.size = 1100, "DISK", 5
    light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(7, -11, 6))
    camera = bpy.context.object
    for owner in list(camera.users_collection): owner.objects.unlink(camera)
    stage.objects.link(camera)
    camera.data.type, camera.data.ortho_scale = "ORTHO", 6.5
    camera.rotation_euler = (Vector((0, 0, 1.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera


def export_model(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children: child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.obj_export(filepath=str(path), export_selected_objects=True, export_materials=True,
        export_uv=True, export_normals=True, export_triangulated_mesh=True,
        forward_axis="NEGATIVE_Z", up_axis="Y")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    GAME_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections): bpy.data.collections.remove(collection)
    scene = bpy.context.scene
    scene["asset_origin"] = "authored_from_scratch"
    scene["asset_style"] = "optimized_military_lowpoly_infantry"
    collection = bpy.data.collections.new("MILITARY_PEOPLE")
    scene.collection.children.link(collection)
    material = palette_material()
    shared = limb_meshes(material)
    roots = [add_model(collection, kind, shared, material) for kind in ("rifleman", "ak", "bazooka", "bomber")]
    for index, root in enumerate(roots): root.location.x = (index - 1.5) * 1.45
    add_preview(scene)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 560
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT / "preview.png")
    bpy.ops.render.render(write_still=True)
    for root in roots: root.location.x = 0.0
    for root in roots: export_model(root, OUT / (root.name.removeprefix("MODEL_").lower() + ".obj"))
    bpy.ops.object.select_all(action="DESELECT")
    for root in roots:
        root.select_set(True)
        for child in root.children: child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(GAME_OUT), export_format="GLB", use_selection=True,
        export_materials="EXPORT", export_normals=True, export_texcoords=True, export_apply=True)
    for index, root in enumerate(roots): root.location.x = (index - 1.5) * 1.45
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "military_people.blend"))
    print("MILITARY_PEOPLE_EXPORT_OK", GAME_OUT)


if __name__ == "__main__":
    main()
