"""Reopen delivered Blender files and compare their OBJ round trips.

Run with Blender --background --factory-startup --python-exit-code 1
--python scripts/blender/validate_exports.py -- assets/models
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh


def inspect(objects):
    points = []
    triangles = vertices = faces = invalid_faces = 0
    materials = set()
    for obj in objects:
        mesh = obj.data
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        for vertex in mesh.vertices:
            point = obj.matrix_world @ vertex.co
            assert all(math.isfinite(v) for v in point), obj.name
            points.append(tuple(point))
        for polygon in mesh.polygons:
            if polygon.area < 1e-12:
                invalid_faces += 1
            assert polygon.material_index < max(1, len(mesh.materials)), obj.name
        materials.update(m.name for m in mesh.materials if m)
    assert points and triangles, "Empty geometry"
    assert invalid_faces == 0, f"{invalid_faces} zero-area faces"
    return {
        "objects": len(objects), "vertices": vertices, "faces": faces,
        "triangles": triangles, "materials": sorted(materials),
        "bounds": [[min(p[i] for p in points) for i in range(3)],
                   [max(p[i] for p in points) for i in range(3)]],
    }


def check_palette(objects, folder, packed=False):
    materials = {slot.material for obj in objects for slot in obj.material_slots if slot.material}
    assert len(materials) == 1, "Pickup must use one shared material"
    material = next(iter(materials))
    textures = [node.image for node in material.node_tree.nodes
                if node.type == "TEX_IMAGE" and node.image]
    assert textures, "Palette texture missing"
    palette = textures[0]
    assert tuple(palette.size) == (32, 32), "Expected tiny 32x32 palette"
    assert (folder / "palette.png").is_file(), "OBJ companion palette missing"
    if packed:
        assert palette.packed_file, "Pack palette into .blend"
    for obj in objects:
        assert obj.data.uv_layers.active, "Pickup UV palette mapping missing"
        for loop in obj.data.uv_layers.active.data:
            assert all(math.isfinite(v) and 0 <= v <= 1 for v in loop.uv), "Invalid palette UV"


def check_closed_normals(objects):
    """Reject inside-out closed components; intentional open detail faces are OK."""
    for mesh in {obj.data for obj in objects}:
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        pending = set(bm.verts)
        try:
            while pending:
                stack = [pending.pop()]
                component = set(stack)
                while stack:
                    vertex = stack.pop()
                    for edge in vertex.link_edges:
                        other = edge.other_vert(vertex)
                        if other in pending:
                            pending.remove(other)
                            component.add(other)
                            stack.append(other)
                edges = {edge for vertex in component for edge in vertex.link_edges}
                if edges and all(edge.is_manifold for edge in edges):
                    faces = {face for vertex in component for face in vertex.link_faces}
                    volume = sum(face.verts[0].co.dot(face.verts[1].co.cross(face.verts[2].co))
                                 for face in faces) / 6
                    assert volume > 0, f"Inverted closed component in {mesh.name}"
        finally:
            bm.free()


def validate(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    collection = bpy.data.collections.get("MODEL")
    assert collection, f"MODEL collection missing: {path}"
    objects = [o for o in collection.all_objects if o.type == "MESH"]
    original = inspect(objects)
    if path.stem == "player":
        assert bpy.context.scene.get("asset_origin") == "authored_from_scratch"
        assert bpy.context.scene.get("asset_type") == "pickup"
        assert original["objects"] == 5, "Expected one body and four wheel assemblies"
        assert original["triangles"] <= 2000, "Pickup triangle budget exceeded"
        assert len({obj.data for obj in objects}) == 2, "Share one wheel mesh across four wheels"
        pivots = [o for o in collection.all_objects if o.type == "EMPTY" and o.name.startswith("PIVOT_WHEEL")]
        assert len(pivots) == 4, "Expected four pickup wheel pivots"
        assert all(sum(child.type == "MESH" for child in p.children) == 1 for p in pivots), "Wheel pivot disconnected"
        check_palette(objects, path.parent, packed=True)
        check_closed_normals(objects)
    obj_path = path.with_suffix(".obj")
    assert obj_path.is_file(), obj_path
    assert path.with_suffix(".mtl").is_file(), "Missing companion materials"
    # Empty the scene without writing to any delivery file.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=str(obj_path), forward_axis="NEGATIVE_Z", up_axis="Y")
    imported_objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    imported = inspect(imported_objects)
    if path.stem == "player":
        assert imported["objects"] == 5, "OBJ must preserve wheel objects"
        check_palette(imported_objects, path.parent)
    assert original["triangles"] == imported["triangles"], (path, original, imported)
    assert set(original["materials"]) == set(imported["materials"]), (path, "material mismatch")
    max_error = max(abs(a-b) for left, right in zip(original["bounds"], imported["bounds"])
                    for a, b in zip(left, right))
    assert max_error < 0.0001, (path, "bounds mismatch", max_error)
    return {"file": str(path), "blend": original, "obj": imported,
            "max_bounds_error": max_error, "status": "passed"}


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["assets/models"]
    root = Path(args[0]).resolve()
    # Validate canonical outputs only, not user-extracted archive copies.
    paths = sorted(p for folder in (root / "player", root / "trees")
                   for p in folder.glob("*.blend") if p.with_suffix(".obj").is_file())
    assert paths, f"No exports found in {root}"
    checks = []
    for path in paths:
        try:
            checks.append(validate(path))
        except Exception as error:
            checks.append({"file": str(path), "status": "failed", "error": str(error)})
            print("EXPORT_VALIDATION_FAILED", path.name, str(error))
    report = {"blender_version": bpy.app.version_string, "checks": checks}
    (root / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    assert all(check["status"] == "passed" for check in checks), "See validation.json for failures"
    print("EXPORT_VALIDATION_PASSED", len(paths))
