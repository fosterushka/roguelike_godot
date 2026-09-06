extends SceneTree

## Exports the same landmark composition assembled during world generation.
## No display primitive is recreated here: pool meshes and material overrides
## are copied from GeneratedWorldView's runtime selection rules.
const Context = preload("res://modules/world/generation/generation_context.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const NaturalMeshes = preload("res://presentation/world/natural_meshes.gd")
const TreeReplacements = preload("res://presentation/world/tree_replacements.gd")
const Palette = preload("res://presentation/world/military_environment_palette.gd")

const OUTPUT := "res://assets/models/monuments/authored_monuments.glb"
const LANDMARKS := ["watchtower", "pumpjack", "rock_spire", "dead_grove", "scrap_yard", "water_tower", "recycling_factory", "cargo_crane", "refinery", "satellite_array"]
const PROPS := ["house", "well", "market_stall", "windmill", "utility_pole", "wreck"]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Source._prepare("world_72841")
	var library := Node3D.new()
	library.name = "AUTHORED_MONUMENTS"
	for index in LANDMARKS.size():
		library.add_child(_composition(LANDMARKS[index], index, false))
	var props := Node3D.new()
	props.name = "REPRESENTATIVE_BUILDING_PROPS"
	library.add_child(props)
	for index in PROPS.size():
		props.add_child(_composition(PROPS[index], index, true))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_scene(library, state)
	if append_error != OK:
		push_error("Cannot assemble monuments GLTF: " + error_string(append_error))
		quit(1)
		return
	var write_error := document.write_to_filesystem(state, OUTPUT)
	if write_error != OK:
		push_error("Cannot export monuments GLTF: " + error_string(write_error))
		quit(1)
		return
	print("AUTHORED_MONUMENTS_EXPORTED roots=%d output=%s" % [library.get_child_count(), OUTPUT])
	library.free()
	quit(0)

func _composition(kind: String, index: int, building_prop: bool) -> Node3D:
	var context := Context.new()
	context.setup(72841 + index * 101)
	var natural := Natural.new()
	natural.setup(context)
	var authored := Authored.new()
	authored.setup(context, natural)
	var root := Node3D.new()
	root.name = ("PROP_" if building_prop else "LANDMARK_") + kind.to_upper()
	if building_prop:
		match kind:
			"house": authored.house(0, 0, 0.21)
			"well": authored.well(0, 0)
			"market_stall": authored.market_stall(0, 0, 0.21)
			"windmill": authored.windmill(0, 0, 0.21)
			"utility_pole": authored.utility_pole(0, 0, 1.0, 0.21)
			"wreck": authored.wreck(0, 0, 1.0)
	else:
		if kind in ["rock_spire", "dead_grove"]:
			authored.call(kind, 0.0, 0.0)
		else:
			authored.call(kind, 0.0, 0.0, 0.21)
	_append_instances(root, context)
	for group: Node3D in context.groups:
		root.add_child(group)
	return root

func _append_instances(root: Node3D, context: RefCounted) -> void:
	var trees := TreeReplacements.prepare(context)
	for pool: String in context.POOLS:
		var values: Array = trees.instances[pool]
		if values.is_empty():
			continue
		var template: Dictionary = Source._templates.world_72841[context.POOLS[pool][0]]
		var natural_mesh: Mesh = NaturalMeshes.mesh_for(pool)
		var material: Material = null
		if natural_mesh == null:
			material = Palette.material_for(_palette_role(pool))
		var batch := Node3D.new()
		batch.name = pool
		root.add_child(batch)
		for index in values.size():
			# TreeReplacements hides displaced legacy instances with a zero basis.
			# GLTF has no valid rotation for that transform, so omit it just as the
			# runtime renderer omits it visually.
			if is_zero_approx(values[index].basis.determinant()):
				continue
			var visual := MeshInstance3D.new()
			visual.name = "%s_%03d" % [pool, index]
			visual.mesh = natural_mesh if natural_mesh != null else template.mesh
			visual.material_override = material
			visual.transform = values[index]
			batch.add_child(visual)

static func _palette_role(pool: String) -> String:
	if pool in ["fencePosts", "fenceRails", "woodStructure"]: return "bark"
	if pool in ["earthStructure", "trenches", "bowls", "rims", "decals", "char"]: return "sand_dark"
	if pool in ["stoneInstances", "rockInstances", "ruinStructure", "scarStructure", "cliffFaces", "cliffStrata"]: return "stone"
	if pool in ["redStructure", "barrelInstances"]: return "rust"
	if pool in ["ironStructure", "metalStructure", "tankInstances", "crateInstances"]: return "iron"
	return "olive"
