extends "res://tests/world_generation_test.gd"
const Context = preload("res://modules/world/generation/generation_context.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Primitives = preload("res://presentation/world/world_primitive_catalog.gd")
const Quality = preload("res://presentation/world/world_quality_models.gd")
const Renderer = preload("res://presentation/world/generated_world_view.gd")
const Trees = preload("res://presentation/world/tree_meshes.gd")
const WorldScale = preload("res://modules/world/world_scale.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/authored_props.json"))
	for fixture: Dictionary in fixtures:
		var context := Context.new()
		context.setup(int(fixture.seed))
		var natural := Natural.new()
		natural.setup(context)
		var authored := Authored.new()
		authored.setup(context, natural)
		authored.callv(fixture.name, fixture.args)
		var label := "%s seed=%d" % [fixture.name, fixture.seed]
		if fixture.name == "critter":
			compare(context.random.state, fixture.state, label + " sheep flock preserves world RNG")
			compare(context.groups.size(), context.ambient_critters.size(), label + " one batched model per sheep")
			compare(context.ambient_critters.size() > 0 and context.ambient_critters.size() <= Authored.Wildlife.FLOCK_SIZE, true, label + " bounded sheep flock")
			for critter: Dictionary in context.ambient_critters:
				compare(critter.kind, "grazer", label + " sheep replaces retired human")
			for group: Node3D in context.groups:
				group.free()
			compare(context.props.size(), 0, label + " no replacement prop")
			continue
		compare(context.random.state, fixture.state, label + " RNG")
		compare(context.props.size(), fixture.props.size(), label + " prop count")
		for index in mini(context.props.size(), fixture.props.size()):
			var p: Dictionary = context.props[index]
			var actual := {"id": p.id, "kind": p.kind, "x": p.position.x, "z": p.position.z, "radius": p.radius, "hp": p.hp, "salvage": p.salvage, "village_id": p.get("village_id")}
			var expected: Dictionary = fixture.props[index]
			if p.kind in ["tree", "deadTree", "building"]:
				var scale := WorldScale.BUILDING_SCALE if p.kind == "building" else WorldScale.TREE_SCALE
				compare(actual.kind, expected.kind, label + " scaled prop kind")
				compare(actual.x, expected.x, label + " scaled prop x")
				compare(actual.z, expected.z, label + " scaled prop z")
				compare(actual.radius, float(expected.radius) * scale, label + " scaled prop radius")
				compare(actual.hp, float(expected.hp) * scale, label + " scaled prop hp")
				compare(actual.salvage, expected.salvage, label + " scaled prop salvage")
				compare(actual.village_id, expected.village_id, label + " scaled prop village")
			else:
				compare(actual, expected, label + " prop")
		var original_groups: Array = context.groups.filter(func(group: Node) -> bool: return not group.get_meta("military_detail", false))
		compare(original_groups.size(), fixture.groups.size(), label + " animation group count")
		for index in mini(original_groups.size(), fixture.groups.size()):
			if fixture.name == "village" and _has_quality_mesh(original_groups[index], "house"):
				compare(Renderer.matrix(original_groups[index].transform), _scaled_matrix(fixture.groups[index].matrix, WorldScale.BUILDING_SCALE), label + " scaled building group matrix", 0.0001)
				compare(_has_quality_mesh(original_groups[index], "house"), true, label + " scaled building keeps authored house mesh")
			else:
				_node(original_groups[index], fixture.groups[index], label + " group " + str(index))
		compare(context.ambient_animators.size(), fixture.animators.size(), label + " animator count")
		for index in mini(context.ambient_animators.size(), fixture.animators.size()):
			for key in fixture.animators[index]:
				compare(context.ambient_animators[index][key], fixture.animators[index][key], label + " animator " + key)
		compare(context.ambient_critters.size(), fixture.critters.size(), label + " critter count")
		for index in mini(context.ambient_critters.size(), fixture.critters.size()):
			for key in fixture.critters[index]:
				var actual = context.ambient_critters[index][key]
				if actual is Vector3:
					actual = [actual.x, actual.y, actual.z]
				compare(actual, fixture.critters[index][key], label + " critter " + key, 0.0001)
		var blockers: Array = fixture.activityBlockers.duplicate(true)
		if fixture.name == "village":
			for blocker: Dictionary in blockers:
				blocker.radius = float(blocker.radius) * WorldScale.BUILDING_SCALE
		compare(context.activity_blockers, blockers, label + " activity blockers")
		var pool_counts := []
		for pool: String in context.POOLS:
			if pool.begins_with("rockMass") or Trees.POOLS.has(pool):
				compare(context.instances[pool].is_empty(), true, label + " additional landscape pool remains unused by authored factories")
				continue
			if pool in ["trenches", "bowls", "rims", "decals", "char"]:
				continue
			pool_counts.append(context.instances[pool].size())
		compare(pool_counts, fixture.poolCounts, label + " pool counts")
		for group: Node3D in context.groups:
			group.free()
	_buffers()
	print("Authored factories: %d checks, %d failures, %d source cases" % [checks, failures, fixtures.size()])
	quit(0 if failures == 0 else 1)

func _node(actual: Node3D, expected: Dictionary, label: String) -> void:
	compare(Renderer.matrix(actual.transform), expected.matrix, label + " XYZ matrix", 0.0001)
	var quality_model := _quality_model(actual)
	if not quality_model.is_empty():
		compare(_has_quality_mesh(actual, quality_model), true, label + " authored quality mesh " + quality_model)
		return
	compare(actual is MeshInstance3D, expected.mesh != null, label + " mesh presence")
	if expected.mesh != null and actual is MeshInstance3D:
		var definition: Dictionary = expected.mesh
		var params: Dictionary = definition.parameters
		var dimensions := []
		var shape := ""
		match str(definition.shape):
			"BoxGeometry":
				shape = "box"
				dimensions = [params.width, params.height, params.depth]
			"CylinderGeometry":
				shape = "cylinder"
				dimensions = [params.radiusTop, params.radiusBottom, params.height, params.radialSegments]
			"ConeGeometry":
				shape = "cone"
				dimensions = [params.radius, params.height, params.radialSegments]
			"IcosahedronGeometry":
				shape = "sphere"
				dimensions = [params.radius]
				compare(params.detail, 1, label + " icosahedron detail")
		var key := shape
		for dimension in dimensions:
			key += ":%.6f" % float(dimension)
		key += ":" + str(definition.material)
		compare(actual.mesh == Primitives.meshes.get(key), true, label + " exact primitive/material " + key)
		compare(actual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, definition.cast, label + " cast shadow")
		compare(not actual.mesh.surface_get_material(0).disable_receive_shadows, definition.receive, label + " receive shadow")
	if actual.has_node("MilitaryStructure"):
		var batch := actual.get_node("MilitaryStructure") as MeshInstance3D
		compare(batch.mesh.get_surface_count() > 0, true, label + " batched geometry exists")
		var static_fixture: Dictionary = expected.duplicate()
		static_fixture.children = expected.children.filter(func(child: Dictionary) -> bool: return child.mesh != null)
		var moving_fixtures: Array = expected.children.filter(func(child: Dictionary) -> bool: return child.mesh == null)
		var moving_nodes: Array = actual.get_children().filter(func(child: Node) -> bool: return child != batch)
		compare(actual.get_child_count(), 1 + moving_fixtures.size(), label + " static pieces merged and moving roots retained")
		for index in mini(moving_nodes.size(), moving_fixtures.size()):
			_node(moving_nodes[index], moving_fixtures[index], label + "/moving/" + str(index))
		var expected_bounds := _fixture_bounds(static_fixture, Transform3D.IDENTITY, true)
		compare(batch.mesh.get_aabb().position.distance_to(expected_bounds.position) < 0.002, true, label + " batch keeps geometry origin")
		compare(batch.mesh.get_aabb().size.distance_to(expected_bounds.size) < 0.002, true, label + " batch keeps geometry dimensions")
		return
	compare(actual.get_child_count(), expected.children.size(), label + " hierarchy count")
	for index in mini(actual.get_child_count(), expected.children.size()):
		_node(actual.get_child(index), expected.children[index], label + "/" + str(index))

func _scaled_matrix(matrix: Array, scale: float) -> Array:
	var result: Array = matrix.duplicate()
	for index in [0, 1, 2, 4, 5, 6, 8, 9, 10]:
		result[index] = float(result[index]) * scale
	return result

func _quality_model(node: Node) -> String:
	for model: String in ["utility_pole", "wreck", "well", "market_stall", "loot_scrap", "grazer", "house", "satellite_dish", "windmill", "windmill_blades", "pumpjack_arm"]:
		if _has_quality_mesh(node, model):
			return model
	return ""

func _has_quality_mesh(node: Node, model: String) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh == Quality.mesh_for(model):
		return true
	for child: Node in node.get_children():
		if _has_quality_mesh(child, model):
			return true
	return false

func _buffers() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/world_primitives.json"))
	compare(Primitives.meshes.size(), source.meshes.size(), "primitive cache size")
	for recipe: Dictionary in source.meshes:
		var mesh: ArrayMesh = Primitives.meshes[recipe.name]
		var arrays := mesh.surface_get_arrays(0)
		compare(arrays[Mesh.ARRAY_VERTEX].size() * 3, recipe.attributes.position.size(), recipe.name + " vertex count")
		for index in arrays[Mesh.ARRAY_VERTEX].size():
			var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			compare([vertex.x, vertex.y, vertex.z], recipe.attributes.position.slice(index * 3, index * 3 + 3), recipe.name + " source vertex", 0.000001)
		compare(Array(arrays[Mesh.ARRAY_INDEX]), recipe.indices, recipe.name + " source winding")

func _fixture_bounds(node: Dictionary, parent: Transform3D, skip_root: bool = false) -> AABB:
	var transform := parent if skip_root else parent * preload("res://presentation/combat/source_animation.gd").matrix(node.matrix)
	var points: Array[Vector3] = []
	if node.mesh != null:
		var recipe: Dictionary = node.mesh
		var args: Dictionary = recipe.parameters
		var shape := "box"
		var dimensions: Array = []
		match str(recipe.shape):
			"BoxGeometry": dimensions = [args.width, args.height, args.depth]
			"CylinderGeometry":
				shape = "cylinder"
				dimensions = [args.radiusTop, args.radiusBottom, args.height, args.radialSegments]
			"ConeGeometry":
				shape = "cone"
				dimensions = [args.radius, args.height, args.radialSegments]
			"IcosahedronGeometry":
				shape = "sphere"
				dimensions = [args.radius]
		var key := shape
		for dimension in dimensions: key += ":%.6f" % float(dimension)
		key += ":" + str(recipe.material)
		var mesh: Mesh = Primitives.meshes[key]
		for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: points.append(transform * vertex)
	for child: Dictionary in node.children:
		var bounds := _fixture_bounds(child, transform)
		points.append(bounds.position)
		points.append(bounds.end)
	var result := AABB(points[0], Vector3.ZERO) if not points.is_empty() else AABB()
	for point: Vector3 in points: result = result.expand(point)
	return result
