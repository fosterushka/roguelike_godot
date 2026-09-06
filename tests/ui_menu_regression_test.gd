extends SceneTree

const Hud = preload("res://presentation/ui/hud.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Actions = preload("res://app/input_actions.gd")
var checks := 0
var failures := 0
var activations := 0
var restarts := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-language-test-%d.cfg" % Time.get_ticks_usec()
	Locale.initialize()
	_check(Locale.language == "en", "Missing language preference defaults to English independently of OS locale")
	_check(Locale.text("НАЧАТЬ ЗАЕЗД") == "START RUN", "Menu source text defaults to English")
	Actions.register()
	_check(InputMap.action_get_events("restart_run").is_empty(), "Restart has no keyboard binding")
	var stale := InputEventKey.new()
	stale.physical_keycode = KEY_R
	InputMap.action_add_event("restart_run", stale)
	Actions.register()
	_check(InputMap.action_get_events("restart_run").is_empty(), "Registration removes stale restart bindings")
	var hud := Hud.new()
	root.add_child(hud)
	hud.set_loading(false)
	hud.set_gameplay_active(true)
	hud.update_run({"player": {}, "wave": 1}, null, 0)
	hud.ability_selected.connect(func(_index: int) -> void: activations += 1)
	hud.restart_requested.connect(func() -> void: restarts += 1)
	hud.language_requested.connect(hud.set_language)
	await process_frame
	await process_frame
	_check(hud._gameplay.is_visible_in_tree(), "Gameplay HUD is visible during a run")
	var ability := hud._hotbar_buttons[0]
	var point := ability.get_global_rect().get_center()
	_click(point)
	_check(activations == 1, "Real pointer input activates the gameplay hotbar")
	hud.set_paused(true)
	await process_frame
	_check(not hud._gameplay.is_visible_in_tree(), "Pause removes gameplay controls from mouse and focus routing")
	_click(point)
	_check(activations == 1, "Pointer at underlying hotbar cannot activate an ability through pause")
	var restart := _button(hud._pause_overlay, "RESTART RUN")
	_check(restart != null, "Pause contains a restart button")
	_click(restart.get_global_rect().get_center())
	_check(restarts == 1, "Pause restart button receives real pointer input")
	var hints := hud._pause_overlay.find_child("ControlTips", true, false) as Label
	_check(hints != null and hints.text.contains("WASD") and not hints.text.contains("Restart"), "Control tips live inside pause and do not advertise R restart")
	_check(hud._gameplay.find_child("ControlTips", true, false) == null, "Gameplay has no persistent control-tip strip")
	_check(_button(hud._pause_overlay, "OPTIONS") != null, "Pause exposes the options entry")
	hud.set_language("ru")
	_check(Locale.language == "ru" and restart.text == "НАЧАТЬ ЗАНОВО", "Language switch updates pause controls")
	var config := ConfigFile.new()
	_check(config.load(Locale.settings_path) == OK and config.get_value("interface", "language") == "ru", "Language selection is persisted")
	Locale._initialized = false
	Locale.language = "en"
	Locale.initialize()
	_check(Locale.language == "ru", "A fresh locale initialization restores Russian")
	_check(Locale.text("Need 90 salvage") == "Нужно 90 лома", "Composed purchase requirements are localized")
	_check(Locale.text("Motor LV 2") == "Двигатель LV 2", "Composed level choice names are localized")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_catalogs.json"))
	var missing: Array[String] = []
	for section in ["modules", "levelUpgrades", "coreUpgrades", "protocols", "contracts", "sidegrades"]:
		var entries: Array = catalog[section] if catalog[section] is Array else catalog[section].values()
		for entry: Dictionary in entries:
			for key in ["name", "title", "desc", "description", "tradeoff"]:
				if entry.has(key) and Locale.text(str(entry[key])) == str(entry[key]):
					missing.append(str(entry[key]))
	_check(missing.is_empty(), "Every displayed catalog name, description and modifier tradeoff has Russian text: " + str(missing))
	hud.show_menu("IRON CARAVAN", "", [{"label": "НАЧАТЬ ЗАЕЗД", "action": "start"}], true)
	_check(not hud._gameplay.is_visible_in_tree() and not hud._pause_overlay.visible, "Main menu remains modal and replaces pause")
	await process_frame
	_click(hud.run_menu._language_button.get_global_rect().get_center())
	_check(Locale.language == "en" and _button(hud.run_menu, "START RUN") != null, "Main menu language switch translates its cached rows")
	hud.hide_menus()
	_check(hud._gameplay.is_visible_in_tree(), "Closing menus restores gameplay controls")
	hud.set_loading(true)
	_check(not hud._gameplay.is_visible_in_tree(), "Loading blocks gameplay controls")
	_enemy_name_checks(hud)
	hud.queue_free()
	await process_frame
	DirAccess.remove_absolute(Locale.settings_path)
	print("UI menu regression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _button(child, caption)
		if found != null:
			return found
	return null

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _enemy_name_checks(hud: CanvasLayer) -> void:
	var cases := {
		"bike": ["RAIDER BIKE", "МОТОЦИКЛ РЕЙДЕРОВ"],
		"buggy": ["RAIDER BUGGY", "БАГГИ РЕЙДЕРОВ"],
		"keep": ["RAIDER CRAWLER", "КРАУЛЕР РЕЙДЕРОВ"],
		"garrison_1": ["RAIDER FOUNDRY I", "ЗАВОД РЕЙДЕРОВ I"],
		"garrison_2": ["RAIDER FOUNDRY II", "ЗАВОД РЕЙДЕРОВ II"],
		"garrison_3": ["RAIDER FOUNDRY III", "ЗАВОД РЕЙДЕРОВ III"],
	}
	for language in ["en", "ru"]:
		hud.set_language(language)
		for kind: String in cases:
			hud.update_run({"player": {}, "focus_id": 42, "enemies": [{"id": 42, "kind": kind, "hp": 75, "max_hp": 100, "position": Vector3.ZERO}]}, null, 0)
			var expected: String = cases[kind][0 if language == "en" else 1]
			_check(hud._target_label.visible and hud._target_label.text == expected + "  75/100\n", "Focused %s renders a readable %s name and retains its health" % [kind, language])
