extends SceneTree
const Context = preload("res://modules/world/generation/generation_context.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Arena = preload("res://presentation/world/arena.tscn")
const World = preload("res://modules/world/world_runtime.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
var checks := 0
var failures := 0
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	preload("res://app/input_actions.gd").register()
	var context := Context.new()
	context.setup(197)
	var natural := Natural.new()
	natural.setup(context)
	var authored := Authored.new()
	authored.setup(context, natural)
	authored.village("test-village", 40, 0, 1)
	authored.well(80, 0)
	authored.market_stall(100, 0)
	authored.utility_pole(120, 0)
	var rocks := preload("res://modules/world/generation/rock_formations.gd").new()
	rocks.setup(context)
	rocks.create({"id": "formation-00", "x": 200.0, "z": 0.0, "radius": 12.0, "rotation": 0.0})
	var arena := Arena.instantiate()
	root.add_child(arena)
	paused = true
	check(arena.rebuild_from_context(context), "Generated village binds to real arena")
	paused = false
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_physics_process(false)
	var combat := Combat.new()
	root.add_child(combat)
	combat.setup(vehicle)
	combat.set_physics_process(false)
	var world := World.new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	world.set_physics_process(false)
	var house: Dictionary = world.props.records.values().filter(func(prop: Dictionary) -> bool: return prop.kind == "building")[0]
	var radius: float = vehicle.get_node("VehicleCollider").shape.radius
	vehicle.position = house.position - Vector3(0, 0, radius + house.radius + 0.08)
	vehicle.motion.x = vehicle.position.x
	vehicle.motion.z = vehicle.position.z
	vehicle.motion.heading = 0
	vehicle.motion.move_heading = 0
	vehicle.motion.speed = 10
	vehicle.motion.throttle = 1
	world.running = true
	var before := vehicle.position
	await physics_frame
	Input.action_press("drive_forward")
	vehicle._physics_process(0.1)
	Input.action_release("drive_forward")
	check(house.destroyed, "Actual collision uses pre-impact speed and destroys village house")
	check(arena._prop_colliders[house.id].collision_layer == 0, "Destroyed house removes its physical blocker immediately")
	check(arena._prop_records[house.id].visual_nodes.all(func(node: Node3D) -> bool: return not node.visible), "Whole generated house and roof disappear")
	check(vehicle.position.z > before.z + 0.1 and vehicle.motion.speed > 3.2, "Vehicle continues through broken house instead of losing all speed")
	var rewards: int = combat.model.pickups.size()
	check(rewards == 1, "Physical destruction yields salvage once")
	world.handle_vehicle_impact(arena._prop_colliders[house.id], 20)
	check(combat.model.pickups.size() == rewards, "Repeated collision cannot duplicate salvage")
	world.reset_run()
	check(not house.destroyed and arena._prop_colliders[house.id].collision_layer == 1, "Restart restores house HP and collision")
	check(arena._prop_records[house.id].visual_nodes.all(func(node: Node3D) -> bool: return node.visible), "Restart restores all house geometry")
	for kind: String in ["well", "stall", "streetlight"]:
		var prop: Dictionary = world.props.records.values().filter(func(item: Dictionary) -> bool: return item.kind == kind)[0]
		var shot := {"kind": "bullet", "previous": prop.position + Vector3(-5, 2.1, 0), "position": prop.position + Vector3(5, 2.1, 0), "damage": 2000.0, "radius": 0.05}
		check(world.handle_projectile(shot) and prop.destroyed, "Upper visible geometry receives projectile damage: " + kind)
		check(arena._prop_records[prop.id].visual_nodes.all(func(node: Node3D) -> bool: return not node.visible), "Destroyed decor visuals clear: " + kind)
	combat.model.fire_projectile("rocket", "player", house.position + Vector3(0, 1.5, -5), house.position + Vector3(0, 1.5, 0), 2000.0)
	combat.model._update_projectiles(0.1)
	combat._publish()
	check(house.destroyed, "Real rocket segment/explosion event destroys village house")
	var rock: Dictionary = world.props.records.values().filter(func(prop: Dictionary) -> bool: return prop.get("rock_obstacle", false))[0]
	check(rock.kind == "boulder" and is_finite(rock.hp) and rock.solid, "Rock collision record keeps finite destructible definition")
	check(arena._collision_nodes.size() == arena._prop_colliders.size(), "Rock sections have no duplicate indestructible collider")
	check(arena._prop_records[rock.id].parts.size() == 1, "Rock record owns one monolithic mesh with no separate cap or shelves")
	var rock_part: Dictionary = arena._prop_records[rock.id].parts[0]
	var rock_view: MultiMeshInstance3D = arena.source_world.get_child(int(rock_part.mesh))
	check(str(rock_view.name).begins_with("rockMass") and rock_view.multimesh.mesh is ArrayMesh, "Physical rock binds to the rendered natural rock mesh pool")
	var initial_transform: Transform3D = preload("res://presentation/combat/source_model.gd")._transform(rock_part.matrix)
	if DisplayServer.get_name() != "headless":
		check(rock_view.multimesh.get_instance_transform(int(rock_part.instance)).is_equal_approx(initial_transform), "Actual monolith renders at its registered collision location")
	var rock_hp: float = rock.hp
	for frame in 30:
		world.props.ram(rock.position, 10.0, true, 1.0 / 60.0)
	check(rock.hp == rock_hp, "Solid rocks receive contact damage once, not per-frame proximity damage")
	world.damage_props(rock.position, 0.1, 10000)
	check(rock.destroyed and arena._prop_colliders[rock.id].collision_layer == 0, "Explosion removes rock collision")
	if DisplayServer.get_name() != "headless":
		check(is_zero_approx(rock_view.multimesh.get_instance_transform(int(rock_part.instance)).basis.determinant()), "Explosion hides the entire rendered monolith instance")
	check(not world.rock_steering.grid.nearby(rock.position, 1).any(func(item: Dictionary) -> bool: return item.id == rock.id), "Enemies stop steering around destroyed rock")
	world.reset_run()
	check(not rock.destroyed and arena._prop_colliders[rock.id].collision_layer == 1, "Restart restores rock HP and physical collision")
	if DisplayServer.get_name() != "headless":
		check(rock_view.multimesh.get_instance_transform(int(rock_part.instance)).is_equal_approx(initial_transform), "Restart restores the complete monolith instance at its original pose")
	check(world.rock_steering.grid.nearby(rock.position, 1).any(func(item: Dictionary) -> bool: return item.id == rock.id), "Restart restores rock navigation")
	for node in [world, combat, vehicle, arena]:
		node.queue_free()
	await process_frame
	print("Village destruction: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
