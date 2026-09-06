extends RefCounted

## Physical inventory silhouettes for the same item ids used by raid loot.
## These are models, not UI glyphs: each item remains readable at thumbnail size.
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
static var _materials: Dictionary = {}

static func build(item: String) -> Node3D:
	if item == "weapon_parts":
		return Equipment.build("ammo_feed")
	var root := Node3D.new()
	root.name = "LootModel_" + item
	match item:
		"fuel_cell":
			_part(root, CylinderMesh.new(), Vector3(0.62, 1.35, 0.62), Vector3(0, 0.68, 0), "7f9d63")
			_part(root, BoxMesh.new(), Vector3(0.36, 0.14, 0.5), Vector3(0, 1.38, 0), "d7d1a6")
		"repair_kit":
			_part(root, BoxMesh.new(), Vector3(1.45, 0.72, 0.82), Vector3(0, 0.36, 0), "a44d40")
			_part(root, BoxMesh.new(), Vector3(0.58, 0.18, 0.18), Vector3(0, 0.82, 0), "d7d1a6")
		"circuit":
			_part(root, BoxMesh.new(), Vector3(1.5, 0.12, 1.0), Vector3(0, 0.18, 0), "3d9b9a")
			_part(root, BoxMesh.new(), Vector3(0.6, 0.2, 0.35), Vector3(-0.28, 0.34, 0), "d6b655")
		"relic":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.38
			ring.outer_radius = 0.72
			_part(root, ring, Vector3.ONE, Vector3(0, 0.7, 0), "b47a9c")
			_part(root, CylinderMesh.new(), Vector3(0.36, 0.45, 0.36), Vector3(0, 0.7, 0), "d7c4db")
		_:
			_part(root, BoxMesh.new(), Vector3(1.45, 0.16, 0.9), Vector3(0, 0.22, 0), "9a8974")
			_part(root, BoxMesh.new(), Vector3(0.9, 0.14, 0.56), Vector3(0.18, 0.48, 0.1), "c6b68c")
	return root

static func _part(parent: Node3D, mesh: PrimitiveMesh, dimensions: Vector3, at: Vector3, color: String) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = dimensions
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = dimensions.x * 0.5
		(mesh as CylinderMesh).bottom_radius = dimensions.z * 0.5
		(mesh as CylinderMesh).height = dimensions.y
	var key := color
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.metallic = 0.35
		material.roughness = 0.62
		_materials[key] = material
	mesh.material = _materials[key]
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	parent.add_child(part)
