extends SceneTree

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-language-flow-%d.cfg" % Time.get_ticks_usec()
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-language-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	_check(game.hud.run_menu._description.text.begins_with("Offline expedition"), "Fresh main menu is English")
	_check(game.hud.run_menu.is_visible_in_tree() and game.hud.run_menu._language_button.visible, "Main menu exposes language settings")
	var actions: Array = []
	for row in game.hud.run_menu._rows.get_children():
		if row is Button:
			actions.append(row.get_meta("action_id", ""))
	_check(actions == ["singleplayer", "multiplayer", "options", "quit"], "Main menu exposes singleplayer, disabled multiplayer, options and quit")
	_check((game.hud.run_menu._rows.get_child(1) as Button).disabled, "Multiplayer is visibly disabled in offline build")
	game._menu_action("singleplayer", "")
	_check(_actions(game.hud.run_menu) == ["raid", "vault", "menu"], "Singleplayer menu exposes raid, vault and back")
	game._menu_action("vault", "")
	_check(game.screen_state == "expedition" and game.hideout_hub.visible, "Vault opens the complete hideout hub")
	game._close_expedition()
	_check(game.screen_state == "menu" and _actions(game.hud.run_menu) == ["raid", "vault", "menu"], "Closing vault returns to singleplayer menu")
	game._menu_action("options", "")
	_check(game.screen_state == "options" and _actions(game.hud.run_menu).has("shake_up"), "Options expose persisted camera and audio controls")
	game._menu_action("language", "")
	_check(game.hud.run_menu._title.text == "НАСТРОЙКИ", "Options rebuild after language switch")
	game._menu_action("options_back", "")
	_check(game.screen_state == "menu" and _actions(game.hud.run_menu) == ["raid", "vault", "menu"], "Options back preserves the singleplayer page")
	game.show_start_menu()
	await process_frame
	await process_frame
	var menu_bounds: Rect2 = game.hud.run_menu._scroll.get_global_rect()
	for button: Control in game.hud.run_menu._rows.get_children():
		if button is Button:
			_check(button.size.y >= 40 and menu_bounds.encloses(button.get_global_rect()), "Main menu action has visible unclipped hit area: " + str(button.get_meta("action_id")))
	game._set_language("ru")
	_check(game.hud.run_menu._description.text.begins_with("Одиночная экспедиция"), "Main menu language switches to Russian")
	await game.restart_run()
	var paused_generation: int = game.combat.model.generation
	game._toggle_pause()
	game._menu_action("options", "")
	game._menu_action("options_back", "")
	_check(game.screen_state == "pause" and paused and game.combat.model.generation == paused_generation, "Pause options return preserves the paused raid")
	game._resume()
	var generation: int = game.combat.model.generation
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.keycode = KEY_R
	event.pressed = true
	root.push_input(event)
	_check(game.combat.model.generation == generation and game.screen_state == "running", "Pressing R during gameplay does not restart")
	game._toggle_armory()
	_check(game.hud.armory.query.placeholder_text == "Поиск по названию или описанию", "Armory search uses Russian")
	_check(game.hud.armory.details.text.contains("Турель M4") and game.hud.armory.details.text.contains("Точный автоматический"), "Armory selected module name and description are localized")
	game._set_language("en")
	_check(game.hud.armory.details.text.contains("M4 Turret") and game.hud.armory.query.placeholder_text == "Search name or description", "Open armory switches back to English")
	game._show_choices()
	_check(not game.hud.run_menu._language_button.visible, "Upgrade screen never offers language settings")
	game._on_combat_event({"kind": "result", "won": false, "wave": 3, "kills": 12, "elapsed": 42})
	_check(not game.hud.run_menu._language_button.visible, "Result screen never offers language settings")
	_check(game.hud.run_menu._description.text.begins_with("Wave 3 · Kills 12 · Time 42s\nAccount XP:"), "Result menu formats English run statistics")
	game._set_language("ru")
	_check(game.hud.run_menu._title.text == "ЗАЕЗД ОКОНЧЕН" and game.hud.run_menu._description.text.begins_with("Волна 3 · Убито 12 · Время 42s\nОпыт профиля:"), "Result language switch rebuilds formatted statistics")
	game._set_language("en")
	_check(game.hud.run_menu._description.text.begins_with("Wave 3 · Kills 12 · Time 42s\nAccount XP:"), "Result statistics remain reversible on repeated language changes")
	game.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(Locale.settings_path)
	print("UI language flow: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _has_caption(node: Node, text: String) -> bool:
	if node is Button and node.text.contains(text):
		return true
	for child in node.get_children():
		if _has_caption(child, text):
			return true
	return false

func _actions(menu: Control) -> Array:
	var result: Array = []
	for row in menu._rows.get_children():
		if row is Button:
			result.append(row.get_meta("action_id", ""))
	return result

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
