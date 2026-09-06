extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var game: Node3D
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/military-world-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	get_window().size = Vector2i(1440, 900)
	get_tree().root.content_scale_size = Vector2i(1440, 900)
	game = Main.instantiate()
	game.profile_path = "/private/tmp/military-world-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.session_flow.clock.intro_remaining = 0.0
	game.session_flow.clock.phase = "running"
	game.world.weather.phase = {"type": "clear", "index": 0, "ends_at": 99999.0}
	game.world._sync_weather_model()
	game.world._publish()
	for frame in 6:
		await get_tree().process_frame
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.sound.set_running(false)
	game.camera.set_process(false)
	game.camera._intro = 0.0
	game.camera.h_offset = 0.0
	game.camera.v_offset = 0.0
	game.hud.visible = false
	await _view(Vector3.ZERO, 38.0, "gameplay-start")
	var landmarks: Array = game.arena.world_layout.landmarks
	var rendered := 0
	var seen: Array[String] = []
	for landmark: Dictionary in landmarks:
		if landmark.type in ["recycling_factory", "satellite_array", "water_tower", "watchtower", "refinery", "cargo_crane"] and rendered < 3 and str(landmark.type) not in seen:
			await _view(Vector3(landmark.x, 2.0, landmark.z), (24.0 if landmark.type in ["watchtower", "water_tower"] else 34.0), "landmark-" + str(landmark.type))
			rendered += 1
			seen.append(str(landmark.type))
	var village: Dictionary = game.arena.world_layout.villages[0]
	await _view(Vector3(village.x, 1.0, village.z), 27.0, "village")
	var trees: Array = game.arena.world_layout.props.filter(func(prop: Dictionary) -> bool: return prop.get("vegetation", false))
	if not trees.is_empty():
		var grove: Dictionary = trees[trees.size() / 2]
		await _view(Vector3(grove.position.x, 2.0, grove.position.z), 36.0, "vegetation")
	print("MILITARY_GAMEPLAY_CAPTURE: %d failures, %d landmarks" % [failures, rendered])
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)

func _view(point: Vector3, span: float, label: String) -> void:
	game.camera.size = span
	game.camera.global_position = point + Vector3(32, 39, 32)
	game.camera.look_at(point)
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var status := shot.save_png("res://docs/validation/military-world/" + label + ".png")
	failures += int(status != OK)
	print("MILITARY_GAMEPLAY_IMAGE %s status=%d" % [label, status])
