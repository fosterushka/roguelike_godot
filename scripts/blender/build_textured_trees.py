"""Build shared solid-color tree silhouettes. Safe to run through Blender MCP."""
from pathlib import Path
import bpy
import bmesh
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/trees_rebuilt'
GAME = ROOT / 'assets/environment'
ATLAS_SIZE = 32
TILE_SIZE = ATLAS_SIZE // 2
TREE_TRIANGLE_BUDGET = 600
TRUNK_SIDES = 8
CROWN_SIDES = 12
SPHERE_RINGS = 6
COLORS = ('705742', 'd6d2bd', '42674b', '819750')
TREE_SPECS = {
    'spruceTrees': {
        'trunk': (5.5, .27, .16, 0),
        'crown': 'cone', 'tile': 2,
        # Four large overlapping tiers, without needles or visible branches.
        'parts': ((0, 0, 3.0, 2.5, 3.8), (0, 0, 4.8, 2.0, 3.4),
                  (0, 0, 6.4, 1.5, 3.0), (0, 0, 7.9, .95, 2.8)),
    },
    'birchTrees': {
        'trunk': (6.0, .25, .14, 1),
        'crown': 'sphere', 'tile': 3,
        # Three simple rounded masses, with a plain pale trunk.
        'parts': ((-1.0, 0, 5.7, 1.9, 2.1), (1.0, .25, 6.1, 1.85, 2.0),
                  (0, 0, 7.25, 1.7, 1.8)),
    },
}


def atlas():
    pixels = [0.0] * (ATLAS_SIZE * ATLAS_SIZE * 4)
    for tile, hex_color in enumerate(COLORS):
        rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]
        for y in range(TILE_SIZE):
            for x in range(TILE_SIZE):
                index = (((tile // 2) * TILE_SIZE + y) * ATLAS_SIZE + (tile % 2) * TILE_SIZE + x) * 4
                pixels[index:index + 4] = [*linear, 1]
    image = bpy.data.images.new('TreeSolidPalette', width=ATLAS_SIZE, height=ATLAS_SIZE, alpha=True)
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(OUT / 'tree_atlas.png')
    image.file_format = 'PNG'
    image.save()
    shutil.copyfile(OUT / 'tree_atlas.png', GAME / 'tree_atlas.png')
    material = bpy.data.materials.new('TreeSolidPalette')
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .95
    texture = material.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = image
    material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
    return material


class TreeBuilder:
    """One geometry/material path for both species, merged into one draw surface."""
    def __init__(self, material):
        self.material = material
        self.parts = []

    def add(self, tile):
        obj = bpy.context.object
        uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='TreeUV')
        for loop in uv.data:
            loop.uv = ((tile % 2 + .5) / 2, (tile // 2 + .5) / 2)
        obj.data.materials.append(self.material)
        for face in obj.data.polygons:
            face.use_smooth = len(face.vertices) <= 4
        self.parts.append(obj)

    def build(self, name, spec):
        height, bottom, top, tile = spec['trunk']
        bpy.ops.mesh.primitive_cone_add(vertices=TRUNK_SIDES, radius1=bottom,
            radius2=top, depth=height, location=(0, 0, height / 2))
        self.add(tile)
        for x, y, z, radius, height in spec['parts']:
            if spec['crown'] == 'cone':
                bpy.ops.mesh.primitive_cone_add(vertices=CROWN_SIDES, radius1=radius,
                    radius2=0, depth=height, location=(x, y, z))
            else:
                bpy.ops.mesh.primitive_uv_sphere_add(segments=CROWN_SIDES,
                    ring_count=SPHERE_RINGS, radius=1, location=(x, y, z))
                bpy.context.object.scale = (radius, radius, height)
            self.add(spec['tile'])
        bpy.ops.object.select_all(action='DESELECT')
        for obj in self.parts:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = self.parts[0]
        bpy.ops.object.join()
        obj = self.parts[0]
        obj.name = name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
        bmesh.ops.triangulate(mesh, faces=list(mesh.faces))
        mesh.to_mesh(obj.data)
        mesh.free()
        return obj


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    GAME.mkdir(parents=True, exist_ok=True)
    previous_scene = bpy.context.window.scene
    scene = bpy.data.scenes.new('Simple Tree Assets')
    bpy.context.window.scene = scene
    try:
        material = atlas()
        models = [TreeBuilder(material).build(name, spec) for name, spec in TREE_SPECS.items()]
        for obj in models:
            assert len(obj.data.polygons) <= TREE_TRIANGLE_BUDGET, obj.name
            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.ops.wm.obj_export(filepath=str(OUT / (obj.name + '.obj')),
                export_selected_objects=True, export_materials=True, forward_axis='NEGATIVE_Z', up_axis='Y')
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(filepath=str(GAME / 'textured_trees.glb'),
            export_format='GLB', use_selection=True, use_active_scene=True)
        stats = {obj.name: {'triangles': len(obj.data.polygons), 'surfaces': len(obj.data.materials),
            'crown_parts': len(TREE_SPECS[obj.name]['parts'])} for obj in models}
        (OUT / 'stats.json').write_text(json.dumps(stats, indent=2) + '\n')
        for index, obj in enumerate(models):
            obj.location.x = index * 8
        bpy.data.libraries.write(str(OUT / 'textured_trees.blend'), {scene}, path_remap='RELATIVE')
        print('TREE_REVISION', stats)
    finally:
        bpy.context.window.scene = previous_scene
        for obj in list(scene.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(scene)


if __name__ == '__main__':
    main()
