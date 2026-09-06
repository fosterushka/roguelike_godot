extends RefCounted

const SCENE := preload("res://assets/environment/military_environment.glb")
const PALETTE := preload("res://assets/environment/military_environment_palette.png")
const TREE_SCENE := preload("res://assets/environment/textured_trees.glb")
const TREE_ATLAS := preload("res://assets/environment/tree_atlas.png")
static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D
static var _tree_material: StandardMaterial3D

static func _textured_tree_material() -> StandardMaterial3D:
	if _tree_material == null:
		_tree_material = StandardMaterial3D.new()
		_tree_material.albedo_texture = TREE_ATLAS
		_tree_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_tree_material.roughness = 0.95
		_tree_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _tree_material

static func _palette_material() -> StandardMaterial3D:
	if _material != null:
		return _material
	_material = StandardMaterial3D.new()
	_material.albedo_texture = PALETTE
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.roughness = 0.92
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _material

static func mesh_for(pool: String) -> Mesh:
	if _meshes.has(pool):
		return _meshes[pool]
	var is_tree := pool in ["spruceTrees", "birchTrees"]
	var scene := (TREE_SCENE if is_tree else SCENE).instantiate()
	var source := scene.find_child(pool, true, false) as MeshInstance3D
	assert(source != null and source.mesh != null, "Missing authored military environment mesh: " + pool)
	var imported: ArrayMesh = source.mesh
	var arrays := imported.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].is_empty():
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for index in colors.size():
			colors[index] = Color.WHITE
		arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _textured_tree_material() if is_tree else _palette_material())
	_meshes[pool] = mesh
	scene.free()
	return _meshes[pool]
