extends SceneTree

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/level-choice-language-%d.cfg" % Time.get_ticks_usec()
	root.size = Vector2i(960, 600)
	root.content_scale_size = root.size
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/level-choice-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game._set_language("ru")
	game.combat.model.player.pending_upgrades = 1
	game._show_choices()
	paused = true
	for frame in 6: await process_frame
	var cards: Array = game.hud.run_menu._choice_controls
	assert(cards.size() == 3)
	var motion := InputEventMouseMotion.new()
	motion.position = cards[1].get_global_rect().get_center()
	root.push_input(motion, true)
	await create_timer(0.3, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/level-up-cards-ru-live.png")
	print("CAPTURE /private/tmp/level-up-cards-ru-live.png")
	game.queue_free()
	await process_frame
	paused = false
	quit()
