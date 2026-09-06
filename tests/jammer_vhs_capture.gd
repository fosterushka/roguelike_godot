extends Node

const Main = preload("res://app/main.tscn")
var game: Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-vhs-capture-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 0
	get_tree().root.add_child(game)
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
	var model: RefCounted = game.combat.model
	model.enemies.clear()
	var enemy: Dictionary = model.spawn_enemy("jammerTruck", model.player.position + Vector3(18, 0, 0))
	model.jammer.reset(model.player, 0)
	game.combat._publish()
	await _capture("clear")
	model.jammer.step(model.player, model.enemies, 1.85)
	game.combat._publish()
	assert(game.hud.jammer_vhs.is_visible_in_tree(), "Actual combat snapshot enables screen effect")
	await _capture("inside")
	enemy.position = model.player.position + Vector3(47.9, 0, 0)
	model.jammer.step(model.player, model.enemies, 5)
	game.combat._publish()
	assert(game.hud.jammer_vhs.intensity >= 0.32, "Radius edge keeps visible interference")
	await _capture("edge")
	enemy.position = model.player.position + Vector3(60, 0, 0)
	model.jammer.step(model.player, model.enemies, 3)
	game.combat._publish()
	assert(not game.hud.jammer_vhs.visible, "Leaving jammer radius clears screen effect")
	await _capture("outside")
	print("JAMMER_VHS_CAPTURE_COMPLETE: 4 images, actual combat snapshot and real radius")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _capture(id: String) -> void:
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_tree().root.get_texture().get_image()
	assert(frame.save_png("/private/tmp/iron-vhs-%s.png" % id) == OK)
