extends SceneTree

const NaturalMeshes = preload("res://presentation/world/natural_meshes.gd")
const Primitives = preload("res://presentation/world/world_primitive_catalog.gd")
const Palette = preload("res://presentation/world/military_environment_palette.gd")
const Library = preload("res://presentation/world/environment_library.gd")
const Generator = preload("res://modules/world/generation/world_generator.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(ResourceLoader.exists("res://assets/environment/military_environment.glb"), "Military environment library is exported as a Godot-loadable GLB")
	var pools := NaturalMeshes.all()
	for pool: String in ["spruceTrees", "birchTrees", "treeTrunks", "treeCrowns", "treeCrownsAlt", "treeBranches", "scrubInstances", "deadBrushInstances", "grassTufts", "flowerInstances", "rockMass0", "rockMass1", "rockMass2", "rockMass3", "rockMass4", "rockMass5"]:
		var mesh: Mesh = pools.get(pool)
		var bounds := mesh.get_aabb() if mesh != null else AABB()
		check(mesh != null and bounds.size.y > 0.2 and bounds.size.x > 0.2 and bounds.size.z > 0.2, "Natural pool has readable authored coverage: " + pool)
		if not pool.begins_with("rockMass"):
			check(mesh == Library.mesh_for(pool), "Natural pool uses the imported military environment GLB mesh: " + pool)
			var material: StandardMaterial3D = mesh.surface_get_material(0)
			check(material != null and material.albedo_texture != null, "Natural pool has a runtime color palette: " + pool)
			check(not material.emission_enabled, "Natural pool responds to scene lighting without glow: " + pool)
	for pool: String in ["spruceTrees", "birchTrees"]:
		var tree_bounds := Library.mesh_for(pool).get_aabb()
		check(absf(tree_bounds.position.y) < 0.01, "Full authored tree begins at ground level: " + pool)
	var primitive_samples := {"iron": [0.24, 3.5, 0.24], "metal": [1.6, 0.14, 0.14], "woodDark": [1.25, 0.04, 0.04], "stoneDark": [1.45, 0.6, 2.2], "enemyRed": [0.78, 0.48, 0.08]}
	for source: String in primitive_samples:
		var node := Primitives.create("box", primitive_samples[source], source)
		check(node.material_override == Palette.material_for(Palette.role_for(source)), "Generated semantic primitive uses military palette: " + source)
		node.free()
	var authored := Authored.new()
	var world := Generator.generate(72841, authored)
	check(world.villages.size() > 0 and world.landmarks.size() > 0 and world.groups.size() > 0, "Live generated world retains village and landmark composition")
	var semantic: Array = world.props.filter(func(prop: Dictionary) -> bool: return prop.kind in ["building", "monument", "ruin", "wreck", "tree", "boulder", "scrub"])
	check(semantic.size() > 80 and world.instances.spruceTrees.size() > 0 and world.instances.rockMass0.size() > 0, "Live generation covers natural props, buildings and monuments through runtime pools")
	for group: Node in world.groups:
		group.free()
	await process_frame
	print("Military environment: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
