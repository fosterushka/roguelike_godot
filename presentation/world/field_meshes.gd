extends RefCounted

const Library = preload("res://presentation/world/environment_library.gd")
const POOLS := ["treeTrunks", "treeCrowns", "treeCrownsAlt", "treeBranches", "scrubInstances", "deadBrushInstances", "grassTufts", "flowerInstances"]

static func mesh_for(pool: String) -> Mesh:
	return Library.mesh_for(pool) if POOLS.has(pool) else null
