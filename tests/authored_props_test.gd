extends "res://tests/world_generation_test.gd"
const Context = preload("res://modules/world/generation/generation_context.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Primitives = preload("res://presentation/world/world_primitive_catalog.gd")
const Renderer = preload("res://presentation/world/generated_world_view.gd")
const Trees = preload("res://presentation/world/tree_meshes.gd")

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
			compare(context.random.state, fixture.state, label + " retired figure preserves RNG")
			compare(context.groups.size(), 0, label + " no human geometry")
			compare(context.ambient_critters.size(), 0, label + " no human ambient entity")
			compare(context.props.size(), 0, label + " no replacement prop")
			continue
		compare(context.random.state, fixture.state, label + " RNG")
		compare(context.props.size(), fixture.props.size(), label + " prop count")
		for index in mini(context.props.size(), fixture.props.size()):
			var p: Dictionary = context.props[index]
			var actual := {"id": p.id, "kind": p.kind, "x": p.position.x, "z": p.position.z, "radius": p.radius, "hp": p.hp, "salvage": p.salvage, "village_id": p.get("village_id")}
			compare(actual, fixture.props[index], label + " prop")
		compare(context.groups.size(), fixture.groups.size(), label + " group count")
		for index in mini(context.groups.size(), fixture.groups.size()):
			_node(context.groups[index], fixture.groups[index], label + " group " + str(index))
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
		compare(context.activity_blockers, fixture.activityBlockers, label + " activity blockers")
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
	compare(actual.get_child_count(), expected.children.size(), label + " hierarchy count")
	for index in mini(actual.get_child_count(), expected.children.size()):
		_node(actual.get_child(index), expected.children[index], label + "/" + str(index))

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
