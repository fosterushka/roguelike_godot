extends Node
const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")
var game: Node
var captures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-unit-capture-language-%d.cfg" % Time.get_ticks_usec()
	for language: String in ["ru", "en"]:
		Locale.set_language(language)
		game = Main.instantiate()
		game.profile_path = "/private/tmp/iron-unit-capture-profile-%d.json" % Time.get_ticks_usec()
		game.run_seed_override = 72841
		get_tree().root.add_child(game)
		await game.game_ready
		game.progression.profile.expedition.credits = 5000
		for type: String in Catalog.TYPES:
			if not game.expedition.caravan.buy_wagon(type):
				push_error("Capture garage purchase failed: " + type)
		await game.restart_run()
		game.combat.model.player.coins = 1500
		game.combat.model.player.pending_upgrades = 0
		game.expedition.caravan.install_attachment("wagon-6", 0, "anti_air_station")
		game.expedition.caravan.install_attachment("wagon-6", 2, "armor_panels")
		game._toggle_armory()
		for dimensions in [Vector2i(960, 600), Vector2i(1280, 800)]:
			get_window().size = dimensions
			get_tree().root.content_scale_size = dimensions
			await get_tree().process_frame
			var panel = game.hud.armory
			panel.mount_selector.carrier.select(0)
			panel.mount_selector.carrier.item_selected.emit(0)
			panel.select_module("assaultRifle")
			await _capture("crawler-%s-%d" % [language, dimensions.x])
			panel.mount_selector.carrier.select(6)
			panel.mount_selector.carrier.item_selected.emit(6)
			panel.select_module("attachment:anti_air_station")
			await _capture("wagon6-%s-%d" % [language, dimensions.x])
		game.queue_free()
		await get_tree().process_frame
		get_tree().paused = false
	print("ARMORY_UNIT_CAPTURE_DONE %d" % captures)
	get_tree().quit()

func _capture(label: String) -> void:
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var path := "/private/tmp/iron-armory-" + label + ".png"
	var panel = game.hud.armory
	print("ARMORY_UNIT_CAPTURE %s save=%d size=%s unit=%s core_end=%.1f details_end=%.1f footer_end=%.1f" % [path, frame.save_png(path), frame.get_size(), panel.mount_selector.selected_carrier(), panel._core_summary.get_global_rect().end.y, panel.details.get_global_rect().end.y, panel.save_status.get_global_rect().end.y])
	captures += 1
