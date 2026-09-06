extends RefCounted

const Context = preload("res://modules/world/generation/generation_context.gd")
const Rocks = preload("res://presentation/world/rock_meshes.gd")
const Trees = preload("res://presentation/world/tree_meshes.gd")

static func mesh_for(pool: String) -> Mesh:
	var mesh: Mesh = Rocks.mesh_for(pool)
	return mesh if mesh != null else Trees.mesh_for(pool)

static func all() -> Dictionary:
	var result := {}
	for pool: String in Context.POOLS:
		var mesh := mesh_for(pool)
		if mesh != null:
			result[pool] = mesh
	return result
