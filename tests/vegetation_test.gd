extends SceneTree

const Generator = preload("res://modules/world/generation/world_generator.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Vegetation = preload("res://modules/world/generation/vegetation_generator.gd")
const Context = preload("res://modules/world/generation/generation_context.gd")
const Layout = preload("res://modules/world/generation/layout_generator.gd")
const Replacements = preload("res://presentation/world/tree_replacements.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Trees = preload("res://presentation/world/tree_meshes.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 12:
			push_error(message)

func _run() -> void:
	var signatures := {}
	for pool: String in Trees.POOLS:
		var mesh := Trees.mesh_for(pool)
		check(mesh == Trees.mesh_for(pool), "Tree meshes reuse cached geometry")
		check(mesh.get_surface_count() == 1, "Whole tree species batches as a single surface")
		check(mesh.get_aabb().size.y > 6.0 and mesh.get_aabb().size.x > 2.0, "Every species has a recognizable full-sized silhouette")
		var arrays := mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_VERTEX].size() == arrays[Mesh.ARRAY_COLOR].size(), "Trunk and foliage colors survive instancing")
		check(arrays[Mesh.ARRAY_INDEX].size() < 6000, "Tree geometry remains bounded below 2000 triangles")
		signatures[str(mesh.get_aabb())] = true
	check(signatures.size() == 2, "Birch and spruce have distinct crown proportions")
	_check_replacements()
	var first: Array = []
	for seed_value in [72841, 0, 991827]:
		var context := Generator.generate(seed_value, Authored.new())
		var vegetation: Array = context.props.filter(func(prop: Dictionary) -> bool: return prop.get("vegetation", false))
		var nearby := 0
		var middle := 0
		var species := {}
		for prop: Dictionary in vegetation:
			var point := Vector2(prop.position.x, prop.position.z)
			nearby += int(point.length() <= 120)
			middle += int(point.length() <= 430)
			species[prop.species] = true
			check(point.length() >= 28, "Spawn and turning area remain free of additional trees")
			check(Layout.distance_to_road(prop.position, context.layout.roads) > 12.0, "Road and shoulder retain at least twelve meters of center clearance")
			check(not context.near_village(point.x, point.y, 32.0), "Additional trees preserve settlement access")
			check(not prop.solid and prop.parts.size() == 1 and prop.parts[0].instance >= 0, "Destructible trees use one instance and create no static body")
		check(vegetation.size() >= 900 and vegetation.size() <= Vegetation.TREE_BUDGET, "Groves add substantial bounded vegetation")
		check(nearby >= 30 and middle >= 400, "Vegetation is visible around the start and early play area")
		check(species.size() == 2 and species.has("spruceTrees") and species.has("birchTrees"), "Every seed contains only birch and spruce")
		print("VEGETATION seed=%d trees=%d within120=%d within430=%d groves=%d" % [seed_value, vegetation.size(), nearby, middle, context.get_meta("vegetation_statistics").groves])
		if seed_value == 72841:
			_check_generated_replacements(context)
			first = vegetation.map(func(prop: Dictionary) -> Array: return [prop.id, prop.species, prop.position])
		for group: Node3D in context.groups:
			group.free()
	var repeat := Generator.generate(72841, Authored.new())
	var repeated: Array = repeat.props.filter(func(prop: Dictionary) -> bool: return prop.get("vegetation", false)).map(func(prop: Dictionary) -> Array: return [prop.id, prop.species, prop.position])
	check(first == repeated, "Repeated seed reproduces complete vegetation positions, species and IDs")
	for group: Node3D in repeat.groups:
		group.free()
	var isolated := Context.new()
	isolated.setup(72841)
	var random_before: int = isolated.random.state
	Vegetation.populate(isolated)
	check(isolated.random.state == random_before, "Additive vegetation never consumes the existing world random stream")
	print("Vegetation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_generated_replacements(context: RefCounted) -> void:
	var before: int = context.random.state
	var original: Dictionary = context.instances.duplicate(true)
	var prepared := Replacements.prepare(context)
	check(context.random.state == before and context.instances == original, "Presentation replacement preserves the shared RNG and legacy instance fixtures")
	for tree: Dictionary in context.get_meta("legacy_tree_views"):
		for part: Dictionary in tree.parts:
			if part.instance >= 0:
				check(prepared.instances[part.pool][part.instance] == Replacements.HIDDEN, "Every old trunk/crown/branch is hidden, including aggregate scenery")
	for prop: Dictionary in context.props:
		if prop.kind not in ["tree", "deadTree"]:
			continue
		var parts := Replacements.parts_for(prop.parts, prepared.parts).filter(func(part: Dictionary) -> bool: return part.instance >= 0)
		check(parts.size() <= 1 and parts.all(func(part: Dictionary) -> bool: return part.pool in Trees.POOLS), "Every visible destructible tree maps to one complete retained species")
	for pool: String in Trees.POOLS:
		check(prepared.instances[pool].size() <= Context.POOLS[pool][1], "Retained tree capacity fits legacy replacements and dense vegetation")

func _check_replacements() -> void:
	var context := Context.new()
	context.setup(91)
	var natural := Natural.new()
	natural.setup(context)
	natural.tree(30, 20)
	natural.tree(50, 20, 1, false, false)
	context.aggregate_destructible = true
	natural.dead_tree(70, 20)
	var prepared := Replacements.prepare(context)
	check(context.get_meta("legacy_tree_views").size() == 3, "Replacement records include non-destructible trees and aggregate dead groves")
	check(prepared.instances.spruceTrees.size() + prepared.instances.birchTrees.size() == 3, "All legacy tree forms become birch or spruce")
	context.setup(92)
	check(not context.has_meta("legacy_tree_views"), "Reusing generator context clears legacy presentation records")
	var world := Source.instantiate("world_72841")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/world_layout.json"))
	var originals: Array = layout.props.filter(func(prop: Dictionary) -> bool: return prop.kind in ["tree", "deadTree"]).duplicate(true)
	var initial_children := world.get_child_count()
	var covered := {}
	for prop: Dictionary in originals:
		for part: Dictionary in prop.parts:
			covered["%d:%d" % [part.mesh, part.instance]] = true
	for mesh_index in [6, 7, 8, 9]:
		var batch := world.get_child(mesh_index) as MultiMeshInstance3D
		for instance_index in batch.multimesh.instance_count:
			check(covered.has("%d:%d" % [mesh_index, instance_index]), "Reference world has no unregistered generic tree geometry left outside replacements")
	Replacements.replace_reference(world, layout)
	check(world.get_child_count() == initial_children + 2, "Reference world adds exactly two tree batches")
	var lookup := {}
	for prop: Dictionary in layout.props:
		lookup[prop.id] = prop
	for original: Dictionary in originals:
		var prop: Dictionary = lookup[original.id]
		check(prop.position == original.position and prop.radius == original.radius and prop.hp == original.hp, "Reference tree gameplay identity and collision are preserved")
		check(prop.parts.size() == 1 and prop.parts[0].mesh >= initial_children, "Reference destroy/reset record owns exactly one new complete tree instance")
		var batch := world.get_child(int(prop.parts[0].mesh)) as MultiMeshInstance3D
		check(str(batch.name) in Trees.POOLS, "Reference tree only uses retained species")
	world.free()
