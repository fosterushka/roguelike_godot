extends SceneTree
const Context = preload("res://modules/world/generation/generation_context.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Manifest = preload("res://modules/world/generation/collision_manifest.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
const World = preload("res://modules/world/world_runtime.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	preload("res://app/input_actions.gd").register()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	var combat := Combat.new()
	root.add_child(combat)
	combat.setup(vehicle)
	var world := World.new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	var old_world_id: int = arena.source_world.get_instance_id()
	var old_prop_id: String = arena.world_layout.props[0].id
	var world_children := world.get_child_count()
	for seed_value in [0, 991827, 0]:
		var context := Context.new()
		context.setup(seed_value)
		context.rock_obstacles = Manifest.generate(seed_value).staticColliders
		var natural := Natural.new()
		natural.setup(context)
		natural.tree(80, 95, 1.1)
		var ownership_probe := Node3D.new()
		context.groups.append(ownership_probe)
		context.props[0].groups = [ownership_probe]
		check(not arena.rebuild_from_context(context), "Rebuild rejects active simulation")
		paused = true
		check(arena.rebuild_from_context(context), "Frozen rebuild accepted")
		world.rebind_world(seed_value)
		check(arena.world_layout.seed == seed_value and not is_instance_id_valid(old_world_id), "New seed replaces and frees previous geometry")
		check(arena.source_world.get_child_count() == context.POOLS.size() + 1, "Replacement source pool nodes remain bounded")
		check(world.get_child_count() == world_children and not world.running, "Rebind preserves bounded runtime children and stays frozen")
		check(not world.props.records.has(old_prop_id) and world.props.records.size() == context.rock_obstacles.size() + 1, "Spatial records entirely replaced")
		check(world.activities._villages.is_empty() and world.activities._village_props.is_empty(), "Old activity anchors and village refs cleared")
		var prop: Dictionary = arena.world_layout.props[0]
		world.damage_props(Vector3(80, 0, 95), 1, 1000)
		check(world.props.records[prop.id].destroyed, "New seed prop receives world damage")
		var part: Dictionary = prop.parts[0]
		var batch: MultiMeshInstance3D = arena.source_world.get_child(part.mesh)
		check(not ownership_probe.visible, "New prop destruction hides its owned scene nodes")
		if DisplayServer.get_name() != "headless":
			check(batch.multimesh.get_instance_transform(part.instance).basis.determinant() == 0, "Real renderer hides correct original pool instance")
		world.reset_run(seed_value)
		check(not world.props.records[prop.id].destroyed and ownership_probe.visible, "Same seed reset restores generated prop")
		old_world_id = arena.source_world.get_instance_id()
		old_prop_id = prop.id
		paused = false
	if DisplayServer.get_name() == "headless":
		print("GPU MultiMesh readback checks skipped: dummy headless renderer")
	print("World rebuild: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
