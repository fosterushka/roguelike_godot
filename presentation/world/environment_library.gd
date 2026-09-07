extends RefCounted

const SCENE := preload("res://assets/environment/military_environment.glb")
const PALETTE := preload("res://assets/environment/military_environment_palette.png")
const TREE_SCENE := preload("res://assets/environment/textured_trees.glb")
const TREE_ATLAS := preload("res://assets/environment/tree_atlas.png")
const TREE_TRIANGLE_BUDGET := 4000
const TREE_DISTANT_TRIANGLE_BUDGET := 2000
const AUTHORED_LOD_SUFFIX := "Distant"
# Use the authored crown at normal world zoom; close gallery views retain detail.
const TREE_LOD_EDGE_LENGTH := 0.08
const INDEX_16_VERTEX_LIMIT := 65536
const INDEX_16_BYTES := 2
const INDEX_32_BYTES := 4

static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D
static var _tree_material: StandardMaterial3D

static func _textured_tree_material() -> StandardMaterial3D:
	if _tree_material == null:
		_tree_material = StandardMaterial3D.new()
		_tree_material.albedo_texture = TREE_ATLAS
		_tree_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_tree_material.vertex_color_use_as_albedo = true
		_tree_material.roughness = 0.95
		_tree_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _tree_material

static func _palette_material() -> StandardMaterial3D:
	if _material != null:
		return _material
	_material = StandardMaterial3D.new()
	_material.albedo_texture = PALETTE
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.92
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _material

static func mesh_for(pool: String) -> Mesh:
	var quality = preload("res://presentation/world/world_quality_models.gd")
	if quality.has_model(pool):
		return quality.mesh_for(pool)
	if _meshes.has(pool):
		return _meshes[pool]
	var is_tree := pool in ["spruceTrees", "birchTrees"]
	var scene := (TREE_SCENE if is_tree else SCENE).instantiate()
	var source := scene.find_child(pool, true, false) as MeshInstance3D
	assert(source != null and source.mesh != null, "Missing authored military environment mesh: " + pool)
	var imported: ArrayMesh = source.mesh
	var arrays := imported.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mesh := imported.duplicate() as ArrayMesh
	if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].is_empty():
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for index in colors.size():
			colors[index] = Color.WHITE
		arrays[Mesh.ARRAY_COLOR] = colors
		# Preserve importer LODs while supplying white colors required by vegetation.
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], _imported_lods(imported))
		mesh.shadow_mesh = imported.shadow_mesh
	var distant := scene.find_child(pool + AUTHORED_LOD_SUFFIX, true, false) as MeshInstance3D
	if is_tree and distant != null:
		mesh = _with_authored_lod(mesh, distant.mesh)
	mesh.surface_set_material(0, _textured_tree_material() if is_tree else _palette_material())
	_meshes[pool] = mesh
	scene.free()
	return _meshes[pool]

static func _imported_lods(mesh: ArrayMesh) -> Dictionary:
	var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var stride := INDEX_16_BYTES if mesh.surface_get_array_len(0) < INDEX_16_VERTEX_LIMIT else INDEX_32_BYTES
	var result := {}
	for lod: Dictionary in surface.get("lods", []):
		var data: PackedByteArray = lod.index_data
		var indices := PackedInt32Array()
		indices.resize(data.size() / stride)
		for index in indices.size():
			indices[index] = data.decode_u16(index * stride) if stride == INDEX_16_BYTES else data.decode_u32(index * stride)
		result[float(lod.edge_length)] = indices
	return result

static func _with_authored_lod(primary: ArrayMesh, distant: ArrayMesh) -> ArrayMesh:
	# Automatic simplification erases disconnected spruce sprays. A small authored
	# crown supplies the distant indices while sharing one runtime surface/draw call.
	var arrays := primary.surface_get_arrays(0)
	var far_arrays := distant.surface_get_arrays(0)
	var vertex_offset: int = arrays[Mesh.ARRAY_VERTEX].size()
	for slot in Mesh.ARRAY_MAX:
		if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
			continue
		if slot == Mesh.ARRAY_COLOR and (far_arrays[slot] == null or far_arrays[slot].is_empty()):
			var colors := PackedColorArray()
			colors.resize(distant.surface_get_array_len(0))
			colors.fill(Color.WHITE)
			far_arrays[slot] = colors
		arrays[slot].append_array(far_arrays[slot])
	var indices: PackedInt32Array = far_arrays[Mesh.ARRAY_INDEX].duplicate()
	for index in indices.size():
		indices[index] += vertex_offset
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {TREE_LOD_EDGE_LENGTH: indices})
	return mesh
