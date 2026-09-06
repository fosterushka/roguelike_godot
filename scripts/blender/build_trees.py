"""Build standalone low-poly world trees from the authored world references.

Run with Blender 5.2+:
  /Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/blender/build_trees.py

The authored game meshes are procedural Godot geometry.  This script keeps the
same two living pools (spruceTrees and birchTrees) and adds the deadTree prop
that appears in world_layout.json.  Blender uses Z-up; source world data is
documented as Y-up and maps as (x, -z, y) when positions are ever transferred.
"""
import bpy
import json
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "trees")
SOURCES = [
    "data/visual_models/world_primitives.json",
    "data/visual_models/world_72841.json",
    "data/visual_models/world_layout.json",
    "presentation/world/tree_meshes.gd",
]

def clean():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)

def material(name, color):
    item = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    item.diffuse_color = (*color, 1.0)
    item.use_nodes = True
    node = item.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1.0)
    node.inputs["Roughness"].default_value = 0.92
    return item

def link_model(obj, mat, name):
    obj.name = name
    obj.data.materials.append(mat)
    obj["asset_role"] = "MODEL"
    obj["source_axis"] = "Y-up source mapped to Blender Z-up: (x, -z, y)"
    return obj

def cone(name, location, depth, radius1, radius2, vertices, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1,
        radius2=radius2, depth=depth, location=location)
    return link_model(bpy.context.object, mat, name)

def branch(name, start, end, radius, mat, sides=6):
    start, end = Vector(start), Vector(end)
    delta = end - start
    obj = cone(name, (start + end) * 0.5, delta.length, radius, radius * .42, sides, mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(delta.normalized())
    return obj

def ico(name, location, scale, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=location)
    obj = link_model(bpy.context.object, mat, name)
    obj.scale = scale
    # Keep the authored low-poly crown language but avoid identical spheres.
    for i, vertex in enumerate(obj.data.vertices):
        vertex.co.x *= 0.92 + ((i * 17) % 9) * .018
        vertex.co.y *= 0.94 + ((i * 11) % 7) * .022
        vertex.co.z *= 0.90 + ((i * 7) % 5) * .025
    # Facets are intentional for readable low-poly foliage.
    return obj

def root_flare(name, trunk_mat):
    for i in range(5):
        angle = i * math.tau / 5 + .21
        branch(name + "_root_%02d" % i, (0, 0, .26),
               (math.cos(angle) * .68, math.sin(angle) * .68, .035), .16, trunk_mat, 5)

def spruce():
    bark = material("spruce_bark", (0.22, 0.105, 0.045))
    bark_dark = material("spruce_bark_dark", (0.12, 0.052, 0.022))
    needle = material("spruce_needles", (0.055, 0.25, 0.12))
    needle_light = material("spruce_needles_light", (0.19, 0.39, 0.16))
    root_flare("spruce", bark_dark)
    cone("spruce_trunk", (0, 0, 3.15), 6.3, .34, .17, 8, bark)
    # Visible whorled branch structure under an irregular layered crown.
    for tier, z in enumerate((1.45, 2.25, 3.05, 3.84, 4.62, 5.38)):
        radius = 2.02 - tier * .285
        for spoke in range(6):
            angle = spoke * math.tau / 6 + tier * .35
            end = (math.cos(angle) * radius * .72, math.sin(angle) * radius * .72, z + .10)
            branch("spruce_branch_%d_%d" % (tier, spoke), (0, 0, z), end, .11 - tier*.008, bark_dark, 5)
        crown = cone("spruce_crown_%02d" % tier, (0.05 * (tier % 2), -.05 * (tier % 3), z + .44),
             1.52, radius, radius * .40, 8, needle if tier % 2 else needle_light)
        # Slightly uneven perimeter makes a needle-whorl outline, not a stack of perfect cones.
        for i, vertex in enumerate(crown.data.vertices):
            if vertex.co.z < 0:
                vertex.co.x *= 0.90 + ((i * 13 + tier) % 5) * .045
                vertex.co.y *= 0.90 + ((i * 7 + tier) % 5) * .045
    cone("spruce_tip", (0, 0, 6.66), 1.85, .46, 0, 8, needle_light)

def birch():
    bark = material("birch_bark", (0.72, 0.68, 0.51))
    bark_dark = material("birch_bark_marks", (0.16, 0.12, 0.075))
    leaf = material("birch_leaf", (0.38, 0.50, 0.16))
    leaf_light = material("birch_leaf_light", (0.65, 0.70, 0.25))
    root_flare("birch", bark_dark)
    cone("birch_trunk", (0, 0, 3.45), 6.9, .30, .17, 8, bark)
    # Sparse irregular black bark patches keep the source's dark detail without a striped-pole look.
    for i in range(12):
        angle = (i * 2.41) % math.tau
        z = .72 + (i % 6) * .83 + (i % 3) * .11
        # Tightly sit on the eight-sided tapered trunk's facet apothem.
        trunk_radius = .30 - .13 * z / 6.9
        facet_radius = trunk_radius * math.cos(math.pi / 8) + .003
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(angle)*facet_radius, math.sin(angle)*facet_radius, z))
        patch = link_model(bpy.context.object, bark_dark, "birch_bark_patch_%02d" % i)
        patch.scale = (.012, .07 + (i % 3)*.035, .026 + (i % 4)*.012)
        patch.rotation_euler[2] = angle
    limbs = [((-0.02,0,3.25),(-1.65,.15,5.15)), ((0,0,3.9),(1.55,-.35,5.72)),
             ((0,0,4.75),(-1.18,-.18,6.30)), ((0,0,5.35),(.92,.25,6.82))]
    for i,(a,b) in enumerate(limbs): branch("birch_limb_%02d" % i, a,b,.135-i*.014,bark,6)
    crowns = [((-1.55,.15,5.25),(1.35,1.18,1.25),leaf), ((1.42,-.35,5.78),(1.42,1.25,1.35),leaf_light),
              ((-0.78,-.15,6.48),(1.30,1.14,1.34),leaf), ((.55,.22,6.86),(1.28,1.08,1.28),leaf_light),
              ((-.08,0,7.55),(1.12,1.00,1.18),leaf)]
    for i,(pos,scale,mat) in enumerate(crowns): ico("birch_crown_%02d"%i,pos,scale,mat)

def dead_tree():
    wood = material("dead_wood", (0.20, 0.10, 0.042))
    cut = material("dead_cut_wood", (0.41, 0.23, 0.09))
    root_flare("dead_tree", wood)
    cone("dead_tree_twisted_trunk", (0,0,3.0), 6.0, .36, .16, 7, wood)
    # Bare, forked silhouette matching dead-grove/deadTree world props.
    limbs = [((0,0,2.3),(-1.55,.18,3.55)), ((0,0,3.35),(1.42,-.12,4.72)),
             ((0,0,4.2),(-.88,-.18,5.78)), ((0,0,4.95),(.64,.16,6.38)),
             ((-1.15,.13,3.25),(-1.72,.45,4.22)), ((1.05,-.09,4.42),(1.78,-.42,5.17))]
    for i,(a,b) in enumerate(limbs):
        branch("dead_tree_branch_%02d"%i,a,b,.15-i*.012,wood,6)
        direction = (Vector(b) - Vector(a)).normalized()
        branch("dead_tree_cut_%02d"%i, Vector(b)-direction*.018, Vector(b)+direction*.018, .10-i*.008, cut, 6)
    cone("dead_tree_break", (0,0,6.05), .30, .16, .04, 7, cut)

BUILDERS = {"spruce_tree": spruce, "birch_tree": birch, "dead_tree": dead_tree}

def model_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]

def consolidate_model(name):
    """One draw-ready MODEL mesh, retaining its few material slots."""
    source = model_objects()
    for obj in bpy.context.selected_objects: obj.select_set(False)
    for obj in source: obj.select_set(True)
    bpy.context.view_layer.objects.active = source[0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name + "_MODEL"
    obj.data.name = name + "_mesh"
    model = bpy.data.collections.new("MODEL")
    bpy.context.scene.collection.children.link(model)
    for collection in list(obj.users_collection): collection.objects.unlink(obj)
    model.objects.link(obj)
    obj["source_pool"] = {"spruce_tree":"spruceTrees", "birch_tree":"birchTrees", "dead_tree":"deadTree"}[name]
    return obj

def export_asset(name):
    os.makedirs(OUT, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    consolidate_model(name)
    for obj in bpy.context.selected_objects: obj.select_set(False)
    for obj in model_objects(): obj.select_set(True)
    bpy.context.view_layer.objects.active = model_objects()[0]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"), check_existing=False)
    # OBJ is exported Y-up for external engines: Blender Z-up converts through
    # forward=-Z, up=Y.  The .blend remains native Blender Z-up.
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT, name + ".obj"), export_materials=True,
        export_normals=True, export_uv=False, export_triangulated_mesh=True,
        forward_axis='NEGATIVE_Z', up_axis='Y', export_selected_objects=True)

def provenance():
    layout = json.load(open(os.path.join(ROOT, "data/visual_models/world_layout.json")))
    raw = json.dumps(layout)
    return {"source_files": SOURCES, "world_seed": layout.get("seed"),
            "source_pools": ["spruceTrees", "birchTrees"],
            "dead_tree_mentions": raw.count("deadTree"),
            "dead_grove_landmarks": raw.count("dead-grove"),
            "axis_conversion": "source Y-up (x,y,z) -> Blender Z-up (x,-z,y)",
            "obj_axis": "exported Y-up (forward=-Z, up=Y)"}

def stats_for_obj(path):
    verts = faces = 0
    materials = set()
    with open(path) as fh:
        for line in fh:
            if line.startswith("v "): verts += 1
            elif line.startswith("f "): faces += 1
            elif line.startswith("usemtl "): materials.add(line.split(maxsplit=1)[1].strip())
    return {"vertices": verts, "triangles": faces, "materials": sorted(materials)}

def preview():
    clean()
    for index, name in enumerate(BUILDERS):
        # Reimporting the exported OBJ is an additional preview-level check of
        # its documented Y-up axis conversion.
        bpy.ops.wm.obj_import(filepath=os.path.join(OUT, name + ".obj"),
            forward_axis='NEGATIVE_Z', up_axis='Y')
        for obj in bpy.context.selected_objects:
            if obj.type == "MESH": obj.location.x += (index - 1) * 6.0
    bpy.ops.mesh.primitive_plane_add(size=24, location=(0,0,-.04))
    ground = material("preview_ground", (.075,.085,.055))
    bpy.context.object.data.materials.append(ground)
    bpy.ops.object.light_add(type='AREA', location=(2,-5,10)); bpy.context.object.data.energy=1200; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=7
    bpy.ops.object.light_add(type='SUN', location=(0,0,8)); bpy.context.object.data.energy=1.5; bpy.context.object.rotation_euler=(math.radians(28),0,math.radians(-28))
    bpy.ops.object.camera_add(location=(13,-26,12)); cam=bpy.context.object; bpy.context.scene.camera=cam
    direction = Vector((0,0,3.5))-cam.location; cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler(); cam.data.lens=52
    cam.data.type='ORTHO'; cam.data.ortho_scale=17.5
    scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=1200; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.filepath=os.path.join(OUT, 'preview.png')
    scene.world.color=(.035,.045,.06); bpy.ops.render.render(write_still=True)

def main():
    os.makedirs(OUT, exist_ok=True)
    report = {"provenance": provenance(), "models": {}}
    for name, builder in BUILDERS.items():
        clean(); builder(); export_asset(name)
        report["models"][name] = stats_for_obj(os.path.join(OUT, name + ".obj"))
    with open(os.path.join(OUT, "stats.json"), "w") as fh: json.dump(report, fh, indent=2)
    preview()

if __name__ == '__main__': main()
