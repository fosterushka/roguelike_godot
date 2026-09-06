extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")

var game: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/military-pickup-capture-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	get_window().size = Vector2i(1280, 800)
	get_tree().root.content_scale_size = Vector2i(1280, 800)
	game = Main.instantiate()
	game.profile_path = "/private/tmp/military-pickup-capture-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.combat.model.player.coins = 1000
	game.combat.buy_upgrade("module:assaultRifle")
	game._sync_progression_stats()
	game.session_flow.clock.intro_remaining = 0.0
	game.session_flow.clock.phase = "running"
	game.world.weather.phase = {"type": "clear", "index": 0, "ends_at": 99999.0}
	game.world._sync_weather_model()
	game.world._publish()
	game.camera.half_height = 16.0
	game.camera.follow_offset = Vector3(16, 21, 16)
	game.camera._intro = 0.0
	for frame in 8:
		await get_tree().process_frame
	await _capture("res://docs/validation/military-pickup/gameplay.png")
	game.camera.half_height = 10.0
	game.camera.follow_offset = Vector3(10, 14, 10)
	for frame in 4:
		await get_tree().process_frame
	game.combat.set_running(false)
	game.world.set_running(false)
	game.vehicle.set_physics_process(false)
	game.camera.set_process(false)
	get_tree().paused = true
	var status := await _capture("res://docs/validation/military-pickup/gameplay-close.png")
	game.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	get_tree().quit(0 if status == OK else 1)

func _capture(destination: String) -> Error:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var status := image.save_png(destination)
	print("MILITARY_PICKUP_CAPTURE %s status=%d size=%s weapons=%d" % [destination, status, image.get_size(), game.combat.model.player.modules.size()])
	return status
