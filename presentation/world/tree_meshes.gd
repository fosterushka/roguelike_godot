extends RefCounted

const POOLS := ["spruceTrees", "birchTrees"]
static var _meshes: Dictionary = {}
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

static func mesh_for(pool: String) -> ArrayMesh:
	if not POOLS.has(pool):
		return null
	if not _meshes.has(pool):
		var builder: RefCounted = load("res://presentation/world/tree_meshes.gd").new()
		_meshes[pool] = builder._build(pool)
	return _meshes[pool]

func _build(pool: String) -> ArrayMesh:
	match pool:
		"spruceTrees": _spruce()
		"birchTrees": _birch()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	return mesh

func _spruce() -> void:
	_cylinder(Vector3(0, 1.8, 0), 3.6, 0.28, 0.16, Color("765a3d"))
	for tier in 4:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 3.0 - tier * 0.64
		cone.height = 3.3 - tier * 0.24
		cone.radial_segments = 10
		cone.rings = 1
		_append(cone, Transform3D(Basis(Vector3.UP, tier * 0.43), Vector3(0, 3.65 + tier * 1.48, 0)), Color("3d7152").lerp(Color("8aaa63"), tier / 4.0))

func _birch() -> void:
	var bark := Color("ddd5b8")
	_cylinder(Vector3(0, 3.1, 0), 6.2, 0.24, 0.12, bark)
	for band in 6:
		_cylinder(Vector3(0, 0.8 + band * 0.72, 0), 0.10, 0.24 - band * 0.012, 0.24 - band * 0.012, Color("655c50"))
	_branch(Vector3(0, 3.3, 0), Vector3(-1.3, 5.5, 0.2), 0.12, bark)
	_branch(Vector3(0, 4.1, 0), Vector3(1.25, 6, -0.35), 0.10, bark)
	_crown(Vector3(-1.25, 5.75, 0), Vector3(1.55, 1.75, 1.3), Color("b3bd63"))
	_crown(Vector3(1.15, 6.4, -0.3), Vector3(1.65, 1.65, 1.35), Color("88ad5b"))
	_crown(Vector3(0.1, 7.3, 0.15), Vector3(1.65, 1.7, 1.4), Color("c0ca74"))

func _cylinder(point: Vector3, height: float, base: float, tip: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = base
	mesh.top_radius = tip
	mesh.radial_segments = 8
	mesh.rings = 1
	_append(mesh, Transform3D(Basis.IDENTITY, point), color)

func _branch(start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = start.distance_to(end)
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.5
	mesh.radial_segments = 6
	mesh.rings = 1
	var basis := Basis(Quaternion(Vector3.UP, (end - start).normalized()))
	_append(mesh, Transform3D(basis, (start + end) * 0.5), color)

func _crown(point: Vector3, size: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 9
	mesh.rings = 4
	_append(mesh, Transform3D(Basis.from_scale(size), point), color)

func _append(mesh: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var start := _vertices.size()
	var normal_basis := transform.basis.inverse().transposed()
	for index in vertices.size():
		var normal := (normal_basis * normals[index]).normalized()
		_vertices.append(transform * vertices[index])
		_normals.append(normal)
		_colors.append(color.lightened(maxf(0, normal.y) * 0.08).darkened(maxf(0, -normal.y) * 0.16))
	for index in indices:
		_indices.append(start + index)
