extends "res://tests/world_generation_test.gd"
const Generator = preload("res://modules/world/generation/world_generator.gd")
const Renderer = preload("res://presentation/world/generated_world_view.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var authored_script = load("res://modules/world/generation/authored_props.gd")
	if authored_script == null:
		push_error("Source authored factory is not implemented; full seed builder is not ready")
		quit(1)
		return
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_builder.json"))
	for fixture: Dictionary in fixtures:
		var context: RefCounted = Generator.generate(int(fixture.seed), authored_script.new())
		var legacy_props: Array = context.props.filter(func(prop: Dictionary) -> bool: return not prop.get("rock_obstacle", false) and not prop.get("vegetation", false))
		compare(legacy_props.size(), fixture.props.size(), "world prop count seed=" + str(fixture.seed))
		for index in mini(legacy_props.size(), fixture.props.size()):
			var actual: Dictionary = legacy_props[index]
			var expected: Dictionary = fixture.props[index]
			for key in ["id", "kind", "radius", "hp", "salvage"]:
				compare(actual[key], expected[key], "seed %d prop %d %s" % [fixture.seed, index, key])
			compare(actual.position.x, expected.x, "prop x")
			compare(actual.position.z, expected.z, "prop z")
			compare(actual.get("village_id"), expected.village_id, "prop village")
		compare(context.rock_obstacles, fixture.rocks, "source rocks")
		var rock_props: Array = context.props.filter(func(prop: Dictionary) -> bool: return prop.get("rock_obstacle", false))
		compare(rock_props.size(), fixture.rocks.size(), "rock collision ownership retained")
		for prop: Dictionary in rock_props:
			compare(prop.parts.size(), 1, "rock formation uses a single destructible mesh")
			compare(str(prop.parts[0].pool).begins_with("rockMass"), true, "rock ownership points to monolith geometry")
		compare(context.instances.cliffFaces.is_empty() and context.instances.cliffStrata.is_empty(), true, "stacked formation pools stay empty")
		compare(context.landmarks, fixture.landmarks, "source landmarks")
		var legacy_terrain: Dictionary = context.terrain_details.duplicate()
		var expected_terrain: Dictionary = fixture.terrainDetails.duplicate()
		legacy_terrain.erase("surfacePebbles")
		expected_terrain.erase("surfacePebbles")
		compare(legacy_terrain, expected_terrain, "terrain counts")
		# Formation meshes no longer consume the small-rock pool's pebble capacity.
		compare(context.terrain_details.surfacePebbles >= fixture.terrainDetails.surfacePebbles, true, "freed rock slots retain at least the original pebbles")
		compare(context.terrain_details.surfacePebbles <= 1631, true, "pebble count remains within the original scatter budget")
		compare(context.rendered_features, fixture.renderedFeatures, "feature counts")
		compare(context.biome_centers, fixture.biomeCenters, "biome coordinates")
		compare(context.roadside_anchors, fixture.roadsideAnchors, "roadside coordinates")
		compare(context.villages.size(), fixture.villages.size(), "village count")
		for index in mini(context.villages.size(), fixture.villages.size()):
			for key in fixture.villages[index]:
				compare(context.villages[index][key], fixture.villages[index][key], "village " + str(key))
		for pool: String in fixture.pools:
			if pool in ["cliffFaces", "cliffStrata", "rockInstances", "stoneInstances"]:
				continue
			compare(context.instances[pool].size(), fixture.pools[pool].count, "source pool count " + pool)
			for sample: Dictionary in fixture.pools[pool].samples:
				if int(sample.index) >= context.instances[pool].size():
					continue
				var matrix := Renderer.matrix(context.instances[pool][int(sample.index)])
				compare(matrix, sample.matrix, "source sample " + pool + " " + str(sample.index), 0.00015)
		for group: Node3D in context.groups:
			group.free()
	print("World builder: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
