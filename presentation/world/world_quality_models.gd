extends RefCounted

## Shared meshes authored in Blender for the high-detail world dressing kit.
## The GLB roots are identity-space MeshInstance3D nodes, so callers own pose.
const SCENE := preload("res://assets/environment/world_quality.glb")

static var _meshes: Dictionary = {}
const MODELS := ["grazer", "house", "well", "market_stall", "utility_pole", "wreck", "satellite_dish", "detail_watchtower", "detail_water_tower", "detail_factory", "detail_crane", "detail_refinery", "detail_pumpjack", "detail_satellite", "barrelInstances", "crateInstances", "tankInstances", "rockMass0", "rockMass1", "rockMass2", "rockMass3", "rockMass4", "rockMass5", "rockInstances", "stoneInstances", "fencePosts", "fenceRails", "deadTrees", "windmill", "windmill_blades", "BunkerAuthored", "BarracksAuthored", "loot_scrap", "loot_circuit", "loot_relic", "loot_repair_kit", "loot_fuel_cell", "projectile_bullet", "projectile_enemy_bullet", "projectile_sabot", "projectile_enemy_sabot", "projectile_rocket", "projectile_enemy_rocket", "projectile_grenade", "projectile_enemy_grenade", "scrubInstances", "deadBrushInstances", "grassTufts", "flowerInstances", "ironStructure", "metalStructure", "woodStructure", "redStructure", "earthStructure", "ruinStructure", "scarStructure", "cliffFaces", "cliffStrata", "pumpjack_arm"]

static func has_model(model: String) -> bool:
	return model in MODELS

static func prepare() -> void:
	if not _meshes.is_empty():
		return
	var scene := SCENE.instantiate()
	for model: String in MODELS:
		var source := scene.find_child(model, true, false) as MeshInstance3D
		assert(source != null and source.mesh != null, "Missing world quality mesh: " + model)
		_meshes[model] = source.mesh
		var material := source.mesh.surface_get_material(0) as StandardMaterial3D
		if material != null:
			material.vertex_color_use_as_albedo = true
	scene.free()

static func mesh_for(model: String) -> Mesh:
	if not has_model(model):
		return null
	prepare()
	return _meshes[model]

static func create(model: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = model
	visual.mesh = mesh_for(model)
	return visual
