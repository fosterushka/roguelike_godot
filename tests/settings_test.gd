extends SceneTree

const Catalog = preload("res://modules/settings/settings_catalog.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if "--capture" in OS.get_cmdline_user_args():
		RenderingServer.force_draw()
	return false

func _run() -> void:
	Locale.settings_path = "/private/tmp/settings-language-%d.cfg" % Time.get_ticks_usec()
	var game = preload("res://app/main.tscn").instantiate()
	game.profile_path = "/private/tmp/settings-profile-%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await game.game_ready
	var settings = game.settings_controller
	game._menu_action("options", "")
	var panel = game.hud.run_menu.settings_panel
	_check(panel.is_visible_in_tree() and panel._tabs.get_child_count() == 3, "Main menu opens three settings tabs")
	settings.change("quality", 2)
	settings.change("fpsLimit", 4)
	settings.change("laptop", true)
	_check(Engine.max_fps == Catalog.LAPTOP_FPS and not game.arena.get_node("WastelandSun").shadow_enabled, "Laptop enables 60 FPS and disables shadows")
	_check(is_equal_approx(root.scaling_3d_scale, Catalog.QUALITY[0].scale), "Laptop applies low render scale")
	settings.change("laptop", false)
	_check(Engine.max_fps == 120 and game.arena.get_node("WastelandSun").shadow_enabled, "Disabling laptop restores prior quality and FPS")
	settings.change("cameraShake", 0.25)
	_check(game.camera.shake_intensity == 0.25 and game.expedition_panel.intensity == 0.25, "Both camera controls share one setting")
	settings.change("effectsVolume", 0.25)
	settings.change("engineVolume", 0.0)
	settings.change("uiVolume", 0.5)
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("CaravanEffects"))), 0.25), "Effects volume reaches audio bus")
	_check(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("CaravanEngine"))) == 0, "Engine can be muted independently")
	_check(game.sound._ui_voice.bus == "CaravanUI", "UI has independent audio routing")
	_check(not settings.bind_key("interact", KEY_W) and not settings.bind_key("interact", KEY_ESCAPE), "Conflicting keys and Escape rejected")
	_check(settings.bind_key("interact", KEY_R), "Free key can be assigned")
	_check(InputMap.action_get_events("interact")[0].physical_keycode == KEY_R, "Remapping reaches gameplay InputMap")
	var persisted: Dictionary = Store.new(game.profile_path).load_profile().settings
	_check(persisted.bindings.get("interact") == KEY_R and persisted.cameraShake == 0.25 and persisted.uiVolume == 0.5, "Profile reload retains controls, camera and volume")
	settings.reset_bindings()
	_check(InputMap.action_get_events("interact")[0].physical_keycode == KEY_E, "Reset restores default keys")
	panel.current_tab = 2
	panel.rebuild()
	for frame in 5: await process_frame
	var forward := _button(panel, "Forward    W")
	_click(forward.get_global_rect().get_center())
	_check(panel._binding == "drive_forward", "Real pointer starts key capture")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_ESCAPE
	key_event.physical_keycode = KEY_ESCAPE
	key_event.pressed = true
	root.push_input(key_event, true)
	_check(game.screen_state == "options" and panel._binding.is_empty(), "Escape cancels capture without closing settings")
	for frame in 5: await process_frame
	forward = _button(panel, "Forward    W")
	_click(forward.get_global_rect().get_center())
	key_event = InputEventKey.new()
	key_event.keycode = KEY_UP
	key_event.physical_keycode = KEY_UP
	key_event.pressed = true
	root.push_input(key_event, true)
	_check(InputMap.action_get_events("drive_forward")[0].physical_keycode == KEY_UP, "Real key input rebinds movement")
	_check(Store.new(game.profile_path).load_profile().settings.bindings.get("drive_forward") == KEY_UP, "Special keys survive JSON reload")
	settings.reset_bindings()
	var invalid := Catalog.normalize({"quality": 999, "masterVolume": "broken", "resolution": -10, "fpsLimit": INF})
	_check(invalid.quality == 2 and invalid.masterVolume == 1.0 and invalid.resolution == 0 and invalid.fpsLimit == 0, "Malformed settings are bounded")
	game._set_language("ru")
	for viewport_size in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		for tab in 3:
			panel.current_tab = tab
			panel.rebuild()
			for frame in 5: await process_frame
			_check(root.get_visible_rect().encloses(panel._column.get_global_rect()), "Centered settings fit viewport %s tab %d" % [viewport_size, tab])
			_check(absf(panel._column.get_global_rect().get_center().x - root.get_visible_rect().get_center().x) < 2.0, "Settings column is centered")
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/private/tmp/settings-%d-%d.png" % [viewport_size.x, tab])
	game._menu_action("options_back", "")
	_check(game.screen_state == "menu", "Back returns to main menu")
	game._set_screen("pause")
	game.hud.set_paused(true)
	game._menu_action("options", "")
	_check(paused and panel.is_visible_in_tree() and not game.hud._pause_overlay.visible, "Pause settings are modal and keep game paused")
	game._menu_action("options_back", "")
	_check(game.screen_state == "pause" and paused and game.hud._pause_overlay.visible, "Back restores pause")
	var profile_path: String = game.profile_path
	game.queue_free()
	await process_frame
	paused = false
	Engine.max_fps = 0
	DirAccess.remove_absolute(profile_path)
	DirAccess.remove_absolute(Locale.settings_path)
	print("Settings: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _button(child, caption)
		if found != null: return found
	return null

func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
