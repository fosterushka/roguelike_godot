extends Node
var root: Window

const Policy = preload("res://modules/world/destruction_policy.gd")
var arena: Node3D
var world: Node3D
var combat: Node3D
var vehicle: CharacterBody3D
var combat_view: Node3D
var vehicle_view: Node3D
var frame_ms: Array[float] = []

func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()

func _run() -> void:
	preload("res://app/input_actions.gd").register()
	root.size = Vector2i(1280, 800)
	arena = preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var context := preload("res://modules/world/generation/generation_context.gd").new()
	context.setup(72841)
	var natural := preload("res://modules/world/generation/natural_props.gd").new()
	natural.setup(context)
	natural.tree(-8, 3, 1.3)
	natural.tree(1, 0, 1.25)
	natural.tree(-2, 0, 1.25)
	natural.boulder(12, -5, 1.2)
	context.props[0].id = _identity("fall", func(id: String) -> bool: return Policy.leaves_stump({"id": id}))
	context.props[1].id = _identity("launch", func(id: String) -> bool: return Policy.roll("72841:0:" + id) < 0.5)
	context.props[2].id = _identity("shatter", func(id: String) -> bool: return Policy.roll("72841:0:" + id) >= 0.5)
	get_tree().paused = true
	arena.rebuild_from_context(context)
	get_tree().paused = false
	vehicle = preload("res://modules/caravan/vehicle_controller.gd").new()
	root.add_child(vehicle)
	vehicle.set_physics_process(false)
	vehicle.position = Vector3(-4, 0, 7)
	vehicle_view = preload("res://presentation/vehicles/vehicle_view.gd").new()
	vehicle_view.name = "VehicleView"
	vehicle.add_child(vehicle_view)
	vehicle.telemetry_changed.connect(vehicle_view.set_telemetry)
	combat = preload("res://modules/combat/combat_runtime.gd").new()
	root.add_child(combat)
	combat.setup(vehicle)
	combat.set_physics_process(false)
	combat.set_running(true)
	vehicle_view.apply_player_state(combat.model.player, combat.model.generation)
	world = preload("res://modules/world/world_runtime.gd").new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	world.set_physics_process(false)
	world.running = true
	combat_view = preload("res://presentation/combat/combat_view.gd").new()
	root.add_child(combat_view)
	combat_view.setup(combat, vehicle)
	world.world_event.connect(combat_view.on_world_event)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 42.0
	root.add_child(camera)
	camera.position = Vector3(24, 20, 30)
	camera.look_at(Vector3(0, 3, 0))
	camera.current = true
	world.set_warmup_visible(true)
	await _render()
	world.set_warmup_visible(false)
	world.props.destroy(world.props.records[context.props[0].id], 1.0, preload("res://modules/world/damage_context.gd").create("collision", Vector3.LEFT, "player"))
	world._flush_prop_events()
	world.tornado.intensity = 1.0
	world.tornado.position = Vector3.ZERO
	combat.model.enemies.clear()
	combat.model.spawn_enemy("rifleman", Vector3(0, 0, 2))
	combat.model.spawn_enemy("buggy", Vector3(-1, 0, -2))
	await _advance(30)
	await _save("fall")
	await _advance(72)
	await _save("fling")
	await _advance(150)
	await _save("land")
	print("TORNADO_CAPTURE: actual arena, prop lifecycle, NPC and vehicle simulation rendered")
	for node: Node in [combat_view, world, combat, vehicle, arena, camera]:
		node.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _identity(prefix: String, predicate: Callable) -> String:
	for index in 1000:
		var id := "%s-%d" % [prefix, index]
		if predicate.call(id):
			return id
	return prefix

func _advance(frames: int) -> void:
	frame_ms.clear()
	for frame in frames:
		var started := Time.get_ticks_usec()
		world.tornado.age += 1.0 / 60.0
		world._update_tornado(1.0 / 60.0)
		vehicle._physics_process(1.0 / 60.0)
		combat._sync_vehicle_to_model()
		combat.model.elapsed += 1.0 / 60.0
		combat._publish()
		vehicle_view.apply_player_state(combat.model.player, combat.model.generation)
		vehicle_view.render_interpolated(1.0)
		world._publish()
		await get_tree().process_frame
		frame_ms.append((Time.get_ticks_usec() - started) / 1000.0)

func _render() -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await get_tree().process_frame

func _save(stage: String) -> void:
	await _render()
	if DisplayServer.get_name() != "headless":
		frame_ms.sort()
		print("TORNADO_FRAME_MS %s n=%d p50=%.2f p95=%.2f max=%.2f (rendered scenario, includes frame pacing)" % [stage, frame_ms.size(), frame_ms[int(frame_ms.size() * 0.5)], frame_ms[mini(frame_ms.size() - 1, int(frame_ms.size() * 0.95))], frame_ms.back()])
		var path := "/tmp/tornado-stage1-%s.png" % stage
		root.get_texture().get_image().save_png(path)
		print(path)
