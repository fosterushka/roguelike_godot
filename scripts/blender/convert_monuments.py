"""Make editable Blender and OBJ exports from Godot's authored landmark GLB."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/models/monuments/authored_monuments.glb"
OUT = ROOT / "assets/models/monuments"

def descendants(node):
    yield node
    for child in node.children:
        yield from descendants(child)

def export_root(root):
    bpy.ops.object.select_all(action="DESELECT")
    for node in descendants(root):
        if node.type == "MESH": node.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.obj_export(filepath=str(OUT / (root.name.lower() + ".obj")),
        export_selected_objects=True, export_materials=True, export_uv=True,
        export_normals=True, export_triangulated_mesh=True,
        forward_axis="NEGATIVE_Z", up_axis="Y")

def main():
    if not SOURCE.exists():
        raise RuntimeError("Run export_monuments.gd first: " + str(SOURCE))
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    library = bpy.data.objects.get("AUTHORED_MONUMENTS")
    if library is None:
        raise RuntimeError("Missing AUTHORED_MONUMENTS root")
    roots = [node for node in library.children if node.name.startswith("LANDMARK_")]
    prop_root = bpy.data.objects.get("REPRESENTATIVE_BUILDING_PROPS")
    if prop_root:
        roots.extend(prop_root.children)
    if len(roots) < 10:
        raise RuntimeError("Expected ten landmark roots, found %d" % len(roots))
    for root in roots:
        export_root(root)
    for index, root in enumerate(roots): root.location = ((index % 4) * 40, (index // 4) * 40, 0)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "authored_monuments.blend"))
    print("AUTHORED_MONUMENTS_CONVERTED roots=%d output=%s" % (len(roots), OUT))

if __name__ == "__main__":
    main()
