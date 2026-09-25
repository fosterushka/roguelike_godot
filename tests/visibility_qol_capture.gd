extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const OUTPUT := "res://docs/validation/qol-audit/images/"
var game: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/qol-visibility-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("ru")
	game = Main.instantiate()
	game.profile_path = "/private/tmp/qol-visibility-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.get_node("OcclusionFade").set_process(false)
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.camera.set_process(false)
	get_tree().paused = true
	game.hud.hide_menus()
	game.hud.set_countdown(0, false)
	game.hud.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_place(Vector3.ZERO, 0.0, 58.0)
	_weather("foggy")
	game.combat.model.player.customization = {"fog_lamps": false}
	_update_vehicle()
	game.world._weather_view.advance_visual(0.0)
	await _capture("fog-lamps-off")
	game.combat.model.player.customization.fog_lamps = true
	_update_vehicle()
	game.world._weather_view.advance_visual(0.0)
	await _capture("fog-lamps-on")
	game.vehicle.motion.heading = PI * 0.5
	game.combat.model.player.heading = PI * 0.5
	_update_vehicle()
	game.world._weather_view.advance_visual(0.0)
	await _capture("fog-lamps-turned")
	game.combat.model.player.customization.fog_lamps = false
	_weather("sunny")
	var records: Array = game.arena.occlusion_records().filter(func(record: Dictionary) -> bool: return record.kind == "tree" and record.bounds.size.y > 7.0)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.length_squared() < b.position.length_squared())
	assert(not records.is_empty(), "Generated world contains occluding trees")
	var obstacle: Dictionary = records[0]
	var point: Vector3 = obstacle.position - Vector3(3.0, 0, 3.0)
	_place(point, 0.0, 34.0)
	_update_vehicle()
	game.world._weather_view.advance_visual(0.0)
	var fade: Node = game.get_node("OcclusionFade")
	fade.clear()
	await _capture("occlusion-before")
	fade.update_state(game.combat.model.snapshot())
	for frame in 20:
		fade._process(1.0 / 60.0)
	assert(not fade._faded.is_empty(), "Actual camera ray activates prop fading")
	print("OCCLUSION_ACTIVE: ", fade._faded.keys())
	await _capture("occlusion-after")
	# A detected hostile behind another canopy uses the same production camera policy.
	fade.clear()
	_place(point + Vector3(10, 0, 0), 0.0, 42.0)
	var enemy: Dictionary = game.combat.model.spawn_enemy("bike", Vector3(point.x, 0, point.z))
	game.combat_view.apply_state(game.combat.model.snapshot())
	await _capture("enemy-occlusion-before")
	fade.update_state(game.combat.model.snapshot())
	for frame in 20:
		fade._process(1.0 / 60.0)
	await _capture("enemy-occlusion-after")
	enemy.dead = true
	game.combat_view.apply_state(game.combat.model.snapshot())
	fade.clear()
	var buildings: Array = game.arena.occlusion_records().filter(func(record: Dictionary) -> bool: return record.kind == "building" and record.bounds.size.y > 4.0)
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.length_squared() < b.position.length_squared())
	if not buildings.is_empty():
		var building: Dictionary = buildings[0]
		var house_point: Vector3 = building.bounds.get_center() - Vector3(2, 0, 2)
		_place(house_point, 0.0, 38.0)
		await _capture("building-occlusion-before")
		fade.update_state(game.combat.model.snapshot())
		for frame in 20:
			fade._process(1.0 / 60.0)
		await _capture("building-occlusion-after")
		fade.clear()
	_place(point + Vector3(35, 0, 0), 0.0, 34.0)
	fade.update_state(game.combat.model.snapshot())
	for frame in 30:
		fade._process(1.0 / 60.0)
	print("OCCLUSION_MOVED: prior prop opacity restored=", not fade._faded.has(obstacle.id))
	fade.clear()
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	print("VISIBILITY_QOL_CAPTURE_OK: player, hostile, building and directional fog states rendered")
	get_tree().quit()

func _place(point: Vector3, heading: float, size: float) -> void:
	point.y = Terrain.height_at(point.x, point.z) + 1.0
	game.vehicle.global_position = point
	game.vehicle.motion.x = point.x
	game.vehicle.motion.z = point.z
	game.vehicle.motion.heading = heading
	game.vehicle.motion.speed = 0.0
	game.combat.model.player.position = point
	game.combat.model.player.heading = heading
	game.combat.model.player.speed = 0.0
	game.camera.global_position = point + Vector3(34, 45, 34)
	game.camera.look_at(point)
	game.camera.size = size
	_update_vehicle()

func _update_vehicle() -> void:
	game.vehicle.player_stats = game.combat.model.player
	var visual: Node3D = game.vehicle.get_node("VehicleView")
	visual.apply_player_state(game.combat.model.player, game.combat.model.generation)
	game.vehicle.physics_pose_advanced.emit(0.0)
	visual.render_interpolated(1.0)

func _weather(type: String) -> void:
	var state: Dictionary = game.world.get_state().duplicate(true)
	state.weather.type = type
	state.weather.phase_data = {"type": type}
	state.game_time = 0.0
	game.world._weather_view.apply_state(state)
	game.combat.model.weather_type = type
	game.combat.model.weather_fog_strength = 1.0 if type == "foggy" else 0.0

func _capture(id: String) -> void:
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var status := get_viewport().get_texture().get_image().save_png(OUTPUT + id + ".png")
	assert(status == OK, "Screenshot saved")
	print("VISIBILITY_CAPTURE ", id)
