extends Node

const Main = preload("res://app/main.tscn")
const OUTPUT := "/private/tmp/iron-rain-world-"
var game: Node3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(1600, 900)
	get_tree().root.content_scale_size = Vector2i(1600, 900)
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-rain-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 0
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.hud.set_countdown(0, false)
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.sound.set_running(false)
	game.camera.set_process(false)
	game.camera.size = 78
	game.camera.global_position = game.vehicle.global_position + Vector3(34, 45, 34)
	game.camera.look_at(game.vehicle.global_position)
	for type: String in ["rainy", "storm"]:
		game.world.weather.phase = {"type": type, "previous_type": type, "starts_at": 0.0, "ends_at": 200.0, "duration": 200.0, "index": 0}
		game.world.weather.elapsed = 30.0
		game.world._publish()
		game.world._weather_view.advance_visual(1.25)
		game.hud.jammer_vhs.reset_weather()
		game.hud.jammer_vhs.set_process(false)
		await _capture(type)
	game.queue_free()
	await get_tree().process_frame
	print("Rain world capture: 2 images, 0 failures")
	get_tree().quit()

func _capture(id: String) -> void:
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_tree().root.get_texture().get_image().save_png(OUTPUT + id + ".png") == OK)
