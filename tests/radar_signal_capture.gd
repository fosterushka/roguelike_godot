extends SceneTree

const Main = preload("res://app/main.tscn")
const RadarRules = preload("res://modules/progression/radar_rules.gd")
const OUTPUT := "/private/tmp/iron-radar-signal-"
var game: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-signal-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 0
	root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.hud.set_countdown(0, false)
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.sound.set_running(false)
	game.camera.set_process(false)
	game.camera._intro = 0.0
	game.camera.size = 70
	game.camera.global_position = Vector3(32, 39, 32)
	game.camera.look_at(Vector3.ZERO)
	game.hud.markers.set_process(false)
	var data: Dictionary = game.combat.get_state().duplicate(true)
	data.enemies = []
	data.player.position = Vector3.ZERO
	var world := {"extraction": {"visible": true, "available": true, "position": Vector3(-500, 0, 0), "distance": 500.0, "sites": [{"id": "site", "position": Vector3(-500, 0, 0)}]}, "activity": {"records": [{"id": "mission", "state": "announced", "type": "scavengerRoute", "position": Vector3(400, 0, 100)}]}}
	for level in [0, 3, 5]:
		data.player.radar_level = level
		data.player.radar_range = RadarRules.range_at(level)
		game.hud.update_run(data, game.camera, 0)
		game.hud.update_world(world)
		game.hud.markers.signal_timers.clear()
		game.hud.markers.advance_signals(RadarRules.SIGNAL_DURATION * 0.5)
		await _capture("mk%d-pulse" % level)
		game.hud.markers.advance_signals(RadarRules.SIGNAL_DURATION)
		await _capture("mk%d-silent" % level)
	game.queue_free()
	await process_frame
	print("RADAR_SIGNAL_CAPTURE: 6 images")
	quit()

func _capture(id: String) -> void:
	game.hud.markers.queue_redraw()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + id + ".png") == OK)
