extends Node

const Main = preload("res://app/main.tscn")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron_caravan_render_profile_%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	await _capture("menu")
	game.hud.menu_action_requested.emit("start", "")
	await game.run_ready
	for frame in 100:
		await get_tree().process_frame
	await _capture("gameplay")
	game._toggle_armory()
	await _capture("armory")
	game._resume()
	var model = game.combat.model
	model.player.coins = 1000
	model.player.level = 4
	game.combat.buy_upgrade("module:bazooka")
	game.combat.buy_upgrade("module:radar")
	game.combat.buy_upgrade("trailer")
	model.player.evolution_tier = 3
	model.enemies.clear()
	model.projectiles.clear()
	for sample in [{"kind": "rifleman", "point": Vector3(8, 0, 10)}, {"kind": "buggy", "point": Vector3(-12, 0, 12)}, {"kind": "shooter", "point": Vector3(10, 0, -12)}, {"kind": "jammerTruck", "point": Vector3(-13, 0, -10)}]:
		model.spawn_enemy(sample.kind, sample.point)
	game.combat.focus_next()
	game._sync_progression_stats()
	game.camera.half_height = 24
	for frame in 12:
		await get_tree().process_frame
	game.combat.set_running(false)
	game.world.set_running(false)
	game.sound.stop_all()
	get_tree().paused = true
	await _capture("loadout")
	game.queue_free()
	await get_tree().process_frame
	print("RENDER_CAPTURE_COMPLETE: menu gameplay armory loadout")
	get_tree().quit()

func _capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_tree().root.get_texture().get_image()
	var destination := "/private/tmp/iron-finish-render-%s.png" % id
	var result := frame.save_png(destination)
	print("CAPTURE %s status=%d size=%s" % [destination, result, frame.get_size()])
