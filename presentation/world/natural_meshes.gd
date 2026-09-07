extends RefCounted

const Context = preload("res://modules/world/generation/generation_context.gd")
const Rocks = preload("res://presentation/world/rock_meshes.gd")
const Trees = preload("res://presentation/world/tree_meshes.gd")
const Field = preload("res://presentation/world/field_meshes.gd")
const Quality = preload("res://presentation/world/world_quality_models.gd")

static func mesh_for(pool: String) -> Mesh:
	var quality: Mesh = Quality.mesh_for(pool)
	if quality != null:
		return quality
	var mesh: Mesh = Rocks.mesh_for(pool)
	if mesh != null: return mesh
	mesh = Trees.mesh_for(pool)
	return mesh if mesh != null else Field.mesh_for(pool)

static func all() -> Dictionary:
	var result := {}
	for pool: String in Context.POOLS:
		var mesh := mesh_for(pool)
		if mesh != null:
			result[pool] = mesh
	return result
