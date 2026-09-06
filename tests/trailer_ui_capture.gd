extends Node
const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var game: Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
func _run() -> void:
	Locale.settings_path = "/private/tmp/trailer-ui-capture-language-%d.cfg" % Time.get_ticks_usec()
	for language: String in ["en", "ru"]:
		Locale.set_language(language)
		get_window().size = Vector2i(960, 600)
		get_tree().root.content_scale_size = Vector2i(960, 600)
		game = Main.instantiate()
		game.profile_path = "/private/tmp/trailer-ui-capture-%d.json" % Time.get_ticks_usec()
		get_tree().root.add_child(game)
		await game.game_ready
		game.progression.profile.expedition.credits = 1500
		game.caravan_flow.open_trailers()
		await _capture(language + "-empty")
		game.caravan_panel.tab = "shop"
		game.caravan_flow.refresh()
		await _capture(language + "-shop")
		game.caravan_flow._action("buy_wagon", "cargo", "")
		await _capture(language + "-equipment")
		game.caravan_flow._action("install_attachment", "attachment:cargo_rack:wagon-1:0", "")
		game.caravan_panel.tab = "wagons"
		game.caravan_flow.refresh()
		await _capture(language + "-convoy")
		game.caravan_flow.close()
		await game.restart_run()
		game.combat.model.player.pending_upgrades = 0
		game._toggle_armory()
		game.hud.armory.select_carrier("wagon-1")
		await _capture(language + "-armory")
		game.queue_free()
		await get_tree().process_frame
		get_tree().paused = false
	print("TRAILER_UI_CAPTURE_DONE")
	get_tree().quit()
func _capture(label: String) -> void:
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "/private/tmp/trailer-ui-" + label + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("TRAILER_UI_CAPTURE ", path)
