extends RefCounted

# Bake static pieces inside one destructible/animated root. The root stays intact
# so destruction IDs and monument machinery animation keep their existing owner.
static func compact(root: Node3D) -> void:
	var surfaces: Dictionary = {}
	var originals: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		if not child is MeshInstance3D or child.mesh == null:
			continue
		originals.append(child)
		for index in child.mesh.get_surface_count():
			var material: Material = child.get_active_material(index)
			if not surfaces.has(material):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builder.set_material(material)
				surfaces[material] = builder
			surfaces[material].append_from(child.mesh, index, child.transform)
	if originals.size() < 3:
		return
	var mesh := ArrayMesh.new()
	for builder: SurfaceTool in surfaces.values():
		builder.commit(mesh)
	var visual := MeshInstance3D.new()
	visual.name = "MilitaryStructure"
	visual.mesh = mesh
	root.add_child(visual)
	for child: MeshInstance3D in originals:
		child.free()
