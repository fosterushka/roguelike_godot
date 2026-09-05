extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var game: Node
var captures := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-expedition-capture-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-expedition-capture-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	game.progression.profile.expedition.stash = {"scrap": 8, "circuit": 3, "relic": 1, "repair_kit": 3, "fuel_cell": 2, "weapon_parts": 1}
	game.progression.profile.expedition.credits = 2000
	game.progression.profile.expedition.xp = 360
	game.expedition.action("equip", "repair_kit")
	game.expedition.action("equip", "fuel_cell")
	game.expedition.action("equip", "weapon_parts")
	game.expedition.action("accept", "road_keeper")
	game._open_expedition()
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600)]:
		await _resize(resolution)
		for language: String in ["en", "ru"]:
			game._set_language(language)
			for tab: String in ["stash", "loadout", "trade", "quests", "upgrades", "settings"]:
				game.expedition_panel.show_state(game.expedition.snapshot(), tab)
				await _capture("%s-%dx%d-%s" % [language, resolution.x, resolution.y, tab])
				if resolution.x == 960 and tab == "trade":
					await _capture_bottom("%s-%dx%d-%s-bottom" % [language, resolution.x, resolution.y, tab])
	game._close_expedition()
	await game.restart_run()
	for frame in 90:
		await get_tree().process_frame
	game.expedition.collect_loot("scrap", 3)
	game.expedition.collect_loot("circuit", 1)
	game.expedition.collect_loot("relic", 1)
	game._update_cargo()
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600)]:
		await _resize(resolution)
		for language: String in ["en", "ru"]:
			game._set_language(language)
			game._open_expedition()
			await _capture("%s-%dx%d-backpack" % [language, resolution.x, resolution.y])
			if resolution.x == 960:
				await _capture_bottom("%s-%dx%d-backpack-bottom" % [language, resolution.x, resolution.y])
			game._close_expedition()
			await _capture("%s-%dx%d-gameplay" % [language, resolution.x, resolution.y])
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	DirAccess.remove_absolute(Locale.settings_path)
	print("EXPEDITION_CAPTURE_COMPLETE: %d images, %d failures" % [captures, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _resize(resolution: Vector2i) -> void:
	get_tree().root.size = resolution
	get_tree().root.content_scale_size = resolution
	for frame in 3:
		await get_tree().process_frame

func _capture(id: String) -> void:
	for frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_tree().root.get_texture().get_image()
	var destination := "/private/tmp/iron-expedition-%s.png" % id
	var status := screenshot.save_png(destination)
	captures += 1
	if status != OK:
		failures += 1
	print("EXPEDITION_CAPTURE %s status=%d size=%s" % [destination, status, screenshot.get_size()])

func _capture_bottom(id: String) -> void:
	var scroll := game.expedition_panel.body.get_parent() as ScrollContainer
	scroll.scroll_vertical = int(game.expedition_panel.body.size.y)
	await _capture(id)
	scroll.scroll_vertical = 0
