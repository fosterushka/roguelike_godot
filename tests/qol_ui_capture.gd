extends Node
const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const OUTPUT := "res://docs/validation/qol-audit/images/"
var game: Node
var captures := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
func _run() -> void:
	Locale.settings_path = "/private/tmp/qol-ui-capture-language-%d.cfg" % Time.get_ticks_usec()
	game = Main.instantiate()
	game.profile_path = "/private/tmp/qol-ui-capture-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	game.progression.profile.expedition.credits = 5000
	game.progression.profile.expedition.stash = {"scrap": 8, "circuit": 3, "relic": 1, "repair_kit": 10, "fuel_cell": 4, "weapon_parts": 2}
	game.expedition.action("equip", "repair_kit", 2)
	game.expedition.action("equip", "fuel_cell", 1)
	game.progression.profile.expedition.last_supplies = {"repair_kit": 3, "fuel_cell": 2}
	game.expedition.caravan.buy_wagon("cargo")
	game.expedition.caravan.install_attachment("wagon-1", 2, "cargo_rack")
	game.expedition.caravan.purchase_customization("mud_tires")
	game.expedition.caravan.purchase_customization("fog_lamps")
	game.expedition.caravan.select_customization("paint", "sand")
	game.expedition.caravan.select_customization("emblem", "stripe")
	game.expedition.caravan.save_build(0, "Supply run")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for dimensions: Vector2i in [Vector2i(960, 600), Vector2i(1280, 800)]:
		get_window().size = dimensions
		get_tree().root.content_scale_size = dimensions
		for language: String in ["en", "ru"]:
			game._set_language(language)
			game._open_expedition()
			game.hideout_hub.select_tab("stash")
			await _capture("%s-%d-supplies" % [language, dimensions.x])
			game.hideout_hub.caravan_page = "wagons"
			game.hideout_hub.select_tab("garage")
			await _capture("%s-%d-garage" % [language, dimensions.x])
			game.caravan_flow._action("configure_wagon", "wagon-1", "")
			game.caravan_flow._action("select_mount", "wagon-1", "2")
			await _capture("%s-%d-equipment" % [language, dimensions.x])
			game.caravan_panel.tab = "customization"
			for category: String in ["tires", "paint", "builds"]:
				game.caravan_panel._customization_category = category
				game.caravan_flow.refresh()
				await _capture("%s-%d-%s" % [language, dimensions.x, category])
			game.hideout_hub.select_tab("armory")
			await _capture("%s-%d-armory" % [language, dimensions.x])
			game._close_expedition()
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	print("QOL_UI_CAPTURE_DONE %d" % captures)
	get_tree().quit()
func _capture(label: String) -> void:
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := OUTPUT + "ui-" + label + ".png"
	var status := get_viewport().get_texture().get_image().save_png(path)
	print("QOL_UI_CAPTURE %s status=%d" % [path, status])
	captures += 1
