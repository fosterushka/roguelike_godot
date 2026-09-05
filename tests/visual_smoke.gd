extends SceneTree
const SourceModel = preload("res://presentation/combat/source_model.gd")
const CombatView = preload("res://presentation/combat/combat_view.gd")
const Runtime = preload("res://modules/combat/combat_runtime.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://app/input_actions.gd").register()
	SourceModel.preload_models()
	var crawler := SourceModel.instantiate("player")
	assert(crawler.get_child_count() >= 76)
	root.add_child(crawler)
	var crawler_bounds := AABB()
	var first := true
	for part in crawler.get_children():
		var bounds: AABB = part.transform * part.get_aabb()
		crawler_bounds = bounds if first else crawler_bounds.merge(bounds)
		first = false
	var casters := 0
	for part in crawler.get_children():
		casters += int(part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(casters == 4, "Original crawler uses four main hull shadow casters")
	assert(crawler_bounds.size.distance_to(Vector3(6.6, 4.8708, 6.17738)) < 0.001)
	var world := SourceModel.instantiate("world_72841")
	assert(world.get_child_count() > 3000)
	root.add_child(world)
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var prop: Dictionary = arena.world_layout.props[0]
	assert(arena.set_prop_destroyed(str(prop.id), true))
	for mesh_index in prop.meshes:
		assert(not arena.source_world.get_child(int(mesh_index)).visible)
	assert(arena.set_prop_destroyed(str(prop.id), false))
	for mesh_index in prop.meshes:
		assert(arena.source_world.get_child(int(mesh_index)).visible)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.setup(vehicle)
	var view := CombatView.new()
	root.add_child(view)
	view.setup(runtime, vehicle)
	assert(view._enemy_model({"kind": "shooter", "type": "drone"}) == "drone")
	assert(view._enemy_model({"kind": "leviathan", "boss": true}) == "boss")
	assert(view._enemy_model({"kind": "bazooka", "type": "soldier"}) == "bazooka")
	view.set_warmup_visible(true)
	view.set_warmup_visible(false)
	var positions := [Vector3(8, 0, 10), Vector3(-8, 0, 14)]
	for index in positions.size():
		runtime.model.spawn_enemy("rifleman", positions[index])
	view.apply_state(runtime.get_state())
	view.on_event({"kind": "explosion", "position": Vector3(10, 0, 10), "radius": 4.0})
	await process_frame
	view.apply_state({"generation": 99, "enemies": [], "projectiles": [], "pickups": []})
	print("VISUAL_SMOKE_OK: exact source crawler/world meshes, reusable combat pools, inert warmup, state reset")
	quit()
