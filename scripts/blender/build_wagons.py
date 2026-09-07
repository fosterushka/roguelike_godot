"""Author six compact military trailer variants from scratch.

The visual meshes are deliberately shared inside each export: all four wheels
use one mesh and every panel uses the same tiny palette material. Equipment
such as guns is exported by build_equipment.py and is mounted at run time.
"""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/wagons"
GAME = ROOT / "assets/vehicles"
sys.path.insert(0, str(Path(__file__).parent))
from pickup_geometry import MeshBuilder, PALETTE, wheel_mesh
from wagon_bodywork import add_bodywork

TYPES = ("cargo", "repair", "weapon", "fuel", "anti_tank", "anti_air")
# Muted role paint; tires, chassis and metal keep their shared neutral palette.
ROLE_PAINT = {
    "cargo": ("807052", "a18d68"),       # canvas / timber
    "repair": ("a18443", "bba064"),      # workshop ochre
    "weapon": ("58694d", "788667"),      # ammunition olive
    "fuel": ("8d4840", "ad6555"),        # oxide red
    "anti_tank": ("626168", "85818a"),   # armored graphite
    "anti_air": ("486b79", "6c8b96"),    # air defense slate blue
}


class WagonBuilder(MeshBuilder):
    """Accept Godot X/Y/Z coordinates while emitting Blender X/Y/Z geometry."""
    def box(self, center, size, color):
        x, y, z = center
        super().box((x, -z, y), (size[0], size[2], size[1]), color)


def gltf_point(point):
    """Godot point to Blender point; glTF import restores the original point."""
    x, y, z = point
    return (x, -z, y)


def palette_material(wagon_type):
    palette = dict(PALETTE)
    palette["paint"], palette["paint_light"] = ROLE_PAINT[wagon_type]
    image = bpy.data.images.new("wagon_%s_palette.png" % wagon_type, 32, 32)
    for index, hex_color in enumerate(palette.values()):
        color = tuple(int(hex_color[channel:channel + 2], 16) / 255 for channel in (0, 2, 4)) + (1,)
        row, column = divmod(index, 4)
        for y in range(row * 8, row * 8 + 8):
            for x in range(column * 8, column * 8 + 8):
                image.pixels[(y * 32 + x) * 4:(y * 32 + x + 1) * 4] = color
    image.filepath_raw = str(OUT / ("wagon_%s_palette.png" % wagon_type))
    image.file_format = "PNG"
    image.save()
    image.pack()
    image.filepath = "//wagon_%s_palette.png" % wagon_type
    material = bpy.data.materials.new("Military_Wagon_%s_Palette" % wagon_type)
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .82
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Closest"
    material.node_tree.links.new(texture.outputs["Color"], material.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return material


def base_mesh(material, wagon_type):
    b = WagonBuilder()
    accent = "paint_light"
    b.box((0, 1.18, 0), (3.18, .18, 3.62), "bed")
    b.box((0, .94, 0), (2.58, .18, 3.48), "trim")
    for side in (-1, 1):
        b.box((side * 1.28, .92, 0), (.18, .22, 3.72), "dark")
        b.box((side * 1.55, 1.53, 0), (.10, .44, 3.50), "paint")
        for y in (-1.55, 1.55):
            b.box((side * 1.80, 1.72, y), (.82, .13, 1.52), "trim")
            b.box((side * 1.80, 1.84, y), (.68, .09, 1.28), "paint_light")
            b.box((side * 1.52, 1.49, y), (.11, .36, 1.50), "paint")
        # Low outer lockboxes keep the crew leg space and mounts clear.
        b.box((side * 1.12, .78, -.10), (.55, .43, 1.20), "dark")
        b.box((side * 1.12, .88, -.72), (.58, .12, .06), accent)
        b.box((side * 1.12, .88, .52), (.58, .12, .06), accent)
        for y in (-1.42, -.50, .42, 1.34): b.box((side * 1.50, 1.72, y), (.10, .08, .07), "accent")
    b.box((0, 1.49, -1.77), (3.16, .48, .11), "paint")
    b.box((0, 1.46, 1.77), (3.16, .42, .11), "paint_light")
    for x in (-1.0, -.5, 0, .5, 1.0): b.box((x, 1.30, 0), (.05, .045, 3.15), "accent")
    # Benches at the two human anchors: crew face +Y / Godot +Z.
    for side in (-1, 1):
        b.box((side * 1.15, 1.81, -1.25), (.62, .12, .57), "accent")
        b.box((side * 1.15, 2.14, -1.55), (.62, .62, .10), "paint")
        b.box((side * .92, 1.49, -1.25), (.07, .54, .12), "steel")
        b.box((side * 1.38, 1.49, -1.25), (.07, .54, .12), "steel")
        b.box((side * 1.15, 1.49, -.68), (.60, .12, .50), "steel")
    # Flat mounts are intentionally unoccupied; shared equipment GLB owns guns.
    for x, y in ((-.85, .70), (.85, .70), (0, -.85)):
        b.box((x, 1.405, y), (.52, .08, .52), "steel")
        b.box((x, 1.455, y), (.32, .035, .32), "accent")
    b.box((0, .94, -2.10), (.34, .24, .55), "steel")
    b.box((0, 1.02, 1.62), (.22, .16, 1.75), "trim")
    for side in (-1, 1): b.box((side * .28, 1.02, 2.35), (.12, .16, 1.75), "trim")
    return b.finish("MilitaryWagon_%s" % wagon_type, material)


def variant_mesh(material, wagon_type):
    b = WagonBuilder()
    add_bodywork(b, wagon_type)
    # Side equipment stays outside the deck mounts and crew seats.
    # They are part of the same authored mesh, adding no runtime scene nodes.
    for side in (-1, 1):
        x = side * 1.70
        if wagon_type == "fuel":
            for z in (-.38, .56):
                first_vertex = len(b.vertices)
                b.box((x, 1.76, z), (.28, .66, .50), "paint")
                # Open carry handle, filler cap and raised reinforcement ribs.
                for dz in (-.15, .15):
                    b.box((x, 2.16, z + dz), (.16, .16, .07), "trim")
                b.box((x, 2.24, z), (.16, .06, .37), "trim")
                b.box((x, 2.11, z + .23), (.19, .08, .12), "steel")
                for dz in (-.13, .13):
                    b.box((x + side * .15, 1.76, z + dz), (.035, .44, .04), "paint_light")
                b.box((x, 1.47, z), (.33, .08, .54), "trim")
                # Tall 1.65m cans define the fuel silhouette from gameplay zoom.
                for index in range(first_vertex, len(b.vertices)):
                    vx, vy, vz = b.vertices[index]
                    b.vertices[index] = (x + (vx-x)*1.65,
                                         -z + (vy+z)*1.5,
                                         1.44 + (vz-1.44)*2.1)
        elif wagon_type == "repair":
            b.box((x, 1.79, 0), (.16, .66, 1.32), "trim")
            outer = x + side * .12
            # Large open-ended spanner.
            b.box((outer, 1.77, -.38), (.08, .45, .10), "white")
            b.box((outer, 2.00, -.38), (.08, .09, .29), "white")
            for dz in (-.11, .11):
                b.box((outer, 2.09, -.38 + dz), (.08, .18, .07), "white")
            # Hammer and screwdriver on the same tool board.
            b.box((outer, 1.78, .04), (.09, .48, .08), "accent")
            b.box((outer, 2.02, .04), (.13, .15, .32), "steel")
            b.box((outer, 1.97, .44), (.07, .30, .06), "white")
            b.box((outer, 1.68, .44), (.12, .28, .13), "paint_light")
        elif wagon_type == "cargo":
            b.box((x, 1.77, 0), (.32, .57, 1.13), "accent")
            for z in (-.39, .39):
                b.box((x + side * .18, 1.77, z), (.05, .62, .10), "trim")
            b.box((x, 2.08, 0), (.36, .07, 1.17), "bed")
        elif wagon_type == "weapon":
            b.box((x, 1.73, 0), (.30, .47, 1.14), "paint")
            b.box((x, 1.99, 0), (.35, .07, 1.20), "trim")
            for z in (-.36, 0, .36):
                b.box((x + side * .17, 1.77, z), (.08, .30, .12), "accent")
                b.box((x + side * .17, 1.96, z), (.07, .09, .08), "steel")
        elif wagon_type == "anti_tank":
            # Long horizontal rocket cases with contrasting end collars.
            for y in (1.62, 1.96):
                b.box((x, y, 0), (.31, .26, 1.35), "bed")
                for z in (-.54, .54):
                    b.box((x, y, z), (.35, .30, .10), "accent")
        elif wagon_type == "anti_air":
            b.box((x, 1.76, 0), (.28, .56, 1.14), "paint")
            # Recognizable ammunition belt along both side lockers.
            for z in (-.42, -.21, 0, .21, .42):
                b.box((x + side * .17, 1.80, z), (.10, .33, .10), "accent")
                b.box((x + side * .17, 2.01, z), (.08, .10, .07), "steel")
    return b.finish("MilitaryWagonDetail_%s" % wagon_type, material)


def link(parent, name, data, collection, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, data); obj.parent = parent; obj.matrix_parent_inverse = Matrix.Identity(4); obj.location = location; collection.objects.link(obj); return obj


def empty(parent, name, collection, location):
    obj = bpy.data.objects.new(name, None); obj.parent = parent; obj.matrix_parent_inverse = Matrix.Identity(4); obj.location = location; collection.objects.link(obj); return obj


def build_variant(wagon_type, material, wheel):
    collection = bpy.data.collections.new("WAGON_" + wagon_type.upper()); bpy.context.scene.collection.children.link(collection)
    root = bpy.data.objects.new("SteeringWheelTrailer", None); root["wagon_type"] = wagon_type; collection.objects.link(root)
    link(root, "WagonDeck", base_mesh(material, wagon_type), collection); link(root, "WagonDetails_" + wagon_type, variant_mesh(material, wagon_type), collection)
    for name, x, y in (("FrontLeftWheel", -1.8, 1.55), ("FrontRightWheel", 1.8, 1.55), ("RearLeftWheel", -1.8, -1.55), ("RearRightWheel", 1.8, -1.55)):
        pivot = empty(root, name, collection, gltf_point((x, .88, y))); pivot["anchor"] = (x, .88, y)
        spin = empty(pivot, "WheelRotation", collection, (0, 0, 0)); link(spin, "AllTerrainTire", wheel, collection)
        spring = empty(root, "SuspensionStrut" + name, collection, gltf_point((x * .86, 1.18, y))); spring["anchor"] = (x * .86, 1.18, y)
    drawbar = empty(root, "SteeringDrawbar", collection, gltf_point((0, .95, 1.55))); drawbar["drawbar_pivot"] = (0, .95, 1.55)
    rails = WagonBuilder()
    for side in (-1, 1): rails.box((side * .28, .0, .80), (.12, .16, 1.90), "trim")
    rails.box((0, 0, 1.70), (.32, .24, .28), "accent"); link(drawbar, "DrawbarFrame", rails.finish("DrawbarFrame", material), collection)
    hitch = empty(drawbar, "Hitch", collection, gltf_point((0, 0, 1.7))); hitch["hitch_local"] = (0, 0, 1.7)
    rear = empty(root, "RearHitch", collection, gltf_point((0, .94, -2.1))); rear["rear_hitch"] = (0, .94, -2.1)
    return collection


def select_collection(collection):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = next((obj for obj in collection.objects if obj.type == "MESH"), None)


def measurements(collection):
    meshes = [obj for obj in collection.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    # Blender X/Y/Z to the game X/Y/Z convention used by this source file.
    game_points = [Vector((point.x, point.z, -point.y)) for point in points]
    low = Vector((min(point.x for point in game_points), min(point.y for point in game_points), min(point.z for point in game_points)))
    high = Vector((max(point.x for point in game_points), max(point.y for point in game_points), max(point.z for point in game_points)))
    return {
        "triangles": sum(len(obj.data.polygons) for obj in meshes),
        "mesh_count": len({obj.data.name for obj in meshes}),
        "material_count": len({material.name for obj in meshes for material in obj.data.materials}),
        "bounds": {"min": [round(value, 3) for value in low], "max": [round(value, 3) for value in high], "size": [round(value, 3) for value in high - low]},
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True); GAME.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections): bpy.data.collections.remove(collection)
    bpy.context.scene["asset_origin"] = "authored_from_scratch"
    wheel = wheel_mesh(palette_material("cargo"))
    # pickup_geometry's authored tire is .705m; trailers share the physics
    # radius of .88m, so scale the one reused wheel resource once.
    wheel.transform(Matrix.Scale(.88 / .705, 4))
    outputs = []; stats = {}
    for wagon_type in TYPES:
        material = palette_material(wagon_type)
        collection = build_variant(wagon_type, material, wheel); select_collection(collection)
        stats[wagon_type] = measurements(collection)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / ("wagon_%s.blend" % wagon_type)), copy=True)
        bpy.ops.wm.obj_export(filepath=str(OUT / ("wagon_%s.obj" % wagon_type)), export_selected_objects=True, export_materials=True, export_uv=True, export_normals=True, export_triangulated_mesh=True, forward_axis="NEGATIVE_Z", up_axis="Y")
        output = GAME / ("military_wagon_%s.glb" % wagon_type)
        bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True, export_image_format="AUTO", export_apply=True)
        outputs.append(output.name); bpy.context.scene.collection.children.unlink(collection)
    (GAME / "military_wagon.glb").write_bytes((GAME / "military_wagon_cargo.glb").read_bytes())
    (OUT / "stats.json").write_text(json.dumps({"asset_type": "military_wagons", "variants": stats, "wheel_count": 4, "glb": outputs}, indent=2) + "\n")


if __name__ == "__main__": main()
