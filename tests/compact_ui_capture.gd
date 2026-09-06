extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var game: Node
var captures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/compact-ui-language-%d.cfg" % Time.get_ticks_usec()
	game = Main.instantiate()
	game.profile_path = "/private/tmp/compact-ui-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	game.progression.profile.expedition.stash = {"scrap": 8, "circuit": 3, "relic": 1, "repair_kit": 3, "fuel_cell": 2, "weapon_parts": 1}
	game.progression.profile.expedition.credits = 2000
	game.expedition.action("equip", "repair_kit")
	game.expedition.action("equip", "fuel_cell")
	for dimensions: Vector2i in [Vector2i(960, 600), Vector2i(1280, 800)]:
		get_window().size = dimensions
		get_tree().root.content_scale_size = dimensions
		for language: String in ["en", "ru"]:
			game.show_start_menu()
			game._set_language(language)
			await _capture("%s-%d-main-menu" % [language, dimensions.x])
			game._menu_action("singleplayer", "")
			await _capture("%s-%d-singleplayer" % [language, dimensions.x])
			game._menu_action("options", "")
			await _capture("%s-%d-options-main" % [language, dimensions.x])
			game._menu_action("options_back", "")
			game._menu_action("singleplayer", "")
			game._open_expedition()
			for tab: String in ["armory", "loadout", "stash", "trade", "upgrades", "quests", "settings"]:
				game.hideout_hub.select_tab(tab)
				await _capture("%s-%d-vault-%s" % [language, dimensions.x, tab])
				if tab == "armory":
					var inspect := game.hud.armory.find_child("Inspect", true, false) as Control
					await _hover_first(inspect)
					assert(game.hud.armory.item_preview_pip.visible, "Armory hover must show the model preview")
					await _capture("%s-%d-armory-hover" % [language, dimensions.x])
				if tab == "trade":
					await _capture_traders(language, dimensions.x)
			game._close_expedition()
	await game.restart_run()
	game.combat.model.player.pending_upgrades = 0
	await get_tree().create_timer(5.0, true).timeout
	for language: String in ["en", "ru"]:
		game._set_language(language)
		get_window().size = Vector2i(960, 600)
		get_tree().root.content_scale_size = Vector2i(960, 600)
		game._toggle_pause()
		game._menu_action("options", "")
		await _capture(language + "-960-options-pause")
		game._menu_action("options_back", "")
		await _capture(language + "-960-pause")
		game._resume()
		await _capture(language + "-960-hud")
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	print("COMPACT_UI_CAPTURE_DONE %d" % captures)
	get_tree().quit()

func _capture(id: String) -> void:
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "/private/tmp/compact-ui-%s.png" % id
	var status := get_viewport().get_texture().get_image().save_png(path)
	print("COMPACT_UI_CAPTURE %s status=%d" % [path, status])
	captures += 1

func _hover_first(control: Control) -> void:
	assert(control != null, "Capture requires an armory inspect control")
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	get_tree().root.push_input(event, true)
	for frame in 3:
		await get_tree().process_frame

func _capture_traders(language: String, width: int) -> void:
	for trader_id in ["mechanic", "quartermaster", "scavenger"]:
		var trader := _trader_button(trader_id)
		assert(trader != null, "Capture requires trader selector: " + trader_id)
		var index := ["mechanic", "quartermaster", "scavenger"].find(trader_id)
		if not trader.disabled:
			var click := InputEventMouseButton.new()
			click.position = trader.get_global_rect().get_center()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			get_tree().root.push_input(click, true)
			click.pressed = false
			get_tree().root.push_input(click, true)
		for frame in 2:
			await get_tree().process_frame
		await _capture("%s-%d-trader-%d" % [language, width, index])

func _trader_button(id: String) -> Button:
	for node in game.expedition_panel.body.get_children():
		if node is HBoxContainer:
			for button in node.get_children():
				if button is Button and str(button.get_meta("trader_id", "")) == id:
					return button
	return null
