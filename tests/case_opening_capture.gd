extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var game: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/case-capture-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	get_window().size = Vector2i(1280, 800)
	get_tree().root.content_scale_size = Vector2i(1280, 800)
	game = Main.instantiate()
	game.profile_path = "/private/tmp/case-capture-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.camera.set_process(false)
	game.combat.model.enemies.clear()
	game.combat.model.spawn_queue.clear()
	game.combat.model.player.pending_upgrades = 0
	var support = game.world.support
	support.airdrops.clear()
	support.heal_carts.clear()
	support.events.clear()
	var drop: Dictionary = support.spawn_airdrop(game.vehicle.global_position)
	drop.landed = true
	drop.height = 0
	support._update_airdrops(0)
	_flush()
	await get_tree().process_frame
	var panel = game.case_flow.panel
	panel.set_process(false)
	panel.advance(0.45)
	await _capture("rolling-en-1280")
	panel.advance(3)
	await _capture("reward-en-1280")
	get_window().size = Vector2i(960, 600)
	get_tree().root.content_scale_size = Vector2i(960, 600)
	game._set_language("ru")
	await _capture("reward-ru-960")
	panel.activate()
	game.vehicle.health = game.vehicle.max_health - 45
	support.spawn_healer(game.vehicle.global_position)
	support._update_healers(0)
	_flush()
	await get_tree().process_frame
	panel.advance(3)
	await _capture("vehicle-ru-960")
	print("CASE_CAPTURE_COMPLETE: actual pickup receipts, EN/RU 1280/960")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _flush() -> void:
	for event: Dictionary in game.world.support.drain_events():
		game.world.world_event.emit(event)

func _capture(label: String) -> void:
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "/private/tmp/iron-case-" + label + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("CASE_CAPTURE " + path)
