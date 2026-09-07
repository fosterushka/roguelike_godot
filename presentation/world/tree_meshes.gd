extends RefCounted

const Library = preload("res://presentation/world/environment_library.gd")
const DEAD_POOL := "deadTrees"
const POOLS := ["spruceTrees", "birchTrees", DEAD_POOL]

static func mesh_for(pool: String) -> Mesh:
	if pool == DEAD_POOL:
		return preload("res://presentation/world/world_quality_models.gd").mesh_for(pool)
	return Library.mesh_for(pool) if POOLS.has(pool) else null
