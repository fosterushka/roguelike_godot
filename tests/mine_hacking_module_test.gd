extends SceneTree

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const MineViews = preload("res://presentation/combat/mine_views.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-mine-language-%d.cfg" % Time.get_ticks_usec()
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-mine-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	await game.restart_run()
	_check(InputMap.action_get_events("interact").any(func(event: InputEvent) -> bool: return event is InputEventKey and (event.physical_keycode == KEY_E or event.keycode == KEY_E)), "The hold interaction is bound to E")
	var model = game.combat.model
	game._toggle_armory()
	model.running = true
	model.enemies.clear()
	model.hazards.reset()
	var owner: Dictionary = model.spawn_enemy("minelayer", Vector3(0, 0, 30))
	var mine: Dictionary = model.hazards.drop(model, owner)
	mine.position = Vector3.ZERO
	model.player.position = Vector3(4, 0, 0)
	_tick(model, 0.9, false)
	_tick(model, 3.1, true)
	_check(mine.allegiance == "enemy" and mine.hack_progress == 0.0, "Without the installed kit, holding E never converts a mine")
	_check(model.hazards.hack_status.requires_module and not model.hazards.hack_status.available, "Nearby mine reports the missing module")
	game.hud.update_run(model.snapshot(), game.camera, game.selected_ability)
	_check(game.hud._hack_label.text == "MINE HACKING KIT REQUIRED", "Missing module has a clear English HUD prompt")
	model.running = false
	model.player.coins = 1000
	game._show_armory()
	await process_frame
	var panel = game.hud.armory
	var install: Button = _action(panel, "module:mineHacker")
	_check(install != null and not install.disabled, "Mine Hacking Kit is purchasable in the actual armory")
	panel._catalog_scroll.ensure_control_visible(install)
	await process_frame
	var coins: int = model.player.coins
	_click(install.get_global_rect().get_center())
	var installed: Array = model.player.modules.filter(func(module: Dictionary) -> bool: return module.type == "mineHacker")
	_check(installed.size() == 1 and model.player.coins == coins - 60, "Actual armory click installs one kit and charges 60 scrap")
	_check(installed.size() == 1 and installed[0].has("mount"), "Purchased kit has a physical equipment mount")
	model.running = true
	_tick(model, 2.9, true)
	_check(mine.allegiance == "enemy" and is_equal_approx(mine.hack_progress, 2.9), "2.9 seconds is insufficient")
	game.hud.update_run(model.snapshot(), game.camera, game.selected_ability)
	_check(game.hud._hack_label.text == "[E] HOLD · HACK 2.9/3 s", "Compact HUD reports continuous hold seconds")
	Locale.set_language("ru")
	game.hud.update_run(model.snapshot(), game.camera, game.selected_ability)
	_check(game.hud._hack_label.text == "[E] УДЕРЖИВАЙТЕ · ВЗЛОМ 2.9/3 с" and Locale.text("Mine Hacking Kit") == "Комплект взлома мин", "Russian switches both hold prompt and module name")
	Locale.set_language("en")
	var remaining_life: float = mine.life
	game.combat.set_running(false)
	_check(mine.hack_progress == 0.0 and not model.hazards.hack_status.active and model.hazards.mines.has(mine), "Runtime pause cancels the hold while retaining the mine")
	_tick(model, 0.1, false)
	_tick(model, 0.1, true)
	_check(mine.life == remaining_life and mine.hack_progress == 0.0, "Release and repress during pause cannot advance mine simulation")
	game.combat.set_running(true)
	_tick(model, 0.1, true)
	_check(mine.allegiance == "enemy" and is_equal_approx(mine.hack_progress, 0.1), "Resume after a paused interruption starts a fresh hold")
	_tick(model, 2.8, true)
	_check(mine.allegiance == "enemy" and is_equal_approx(mine.hack_progress, 2.9), "The restarted hold still requires the full three seconds")
	_tick(model, 0.1, true)
	_check(mine.allegiance == "friendly", "Three uninterrupted seconds converts the mine")
	_check(MineViews.appearance(mine).color.to_html(false) == "36e47a", "Converted mine uses the existing green visual")
	var hp: float = model.player.hp
	model.player.position = Vector3.ZERO
	_tick(model, 0.1, false)
	_check(not mine.dead and model.player.hp == hp, "Player crossing a friendly mine neither triggers it nor takes damage")
	var ally: Dictionary = model.spawn_enemy("buggy", Vector3.ZERO)
	ally.allegiance = "friendly"
	var neutral: Dictionary = model.spawn_enemy("buggy", Vector3.ZERO)
	neutral.counts_as_hostile = false
	_tick(model, 0.1, false)
	_check(not mine.dead, "Friendly and nonhostile NPCs cannot trigger converted mines")
	var ally_hp: float = ally.hp
	var neutral_hp: float = neutral.hp
	owner.position = Vector3.ZERO
	owner.hp = 100.0
	_tick(model, 0.1, false)
	_check(mine.dead and owner.hp == 70.0 and model.hazards.mines.is_empty(), "Hostile crossing triggers the mine and deals 30 damage exactly once")
	_check(ally.hp == ally_hp and neutral.hp == neutral_hp and model.player.hp == hp, "Friendly explosion affects only hostile enemies")
	_tick(model, 0.1, false)
	_check(owner.hp == 70.0, "Consumed mine cannot damage twice")
	owner.position = Vector3(0, 0, 30)
	model.hazards.reset()
	mine = model.hazards.drop(model, owner)
	mine.position = Vector3.ZERO
	model.player.position = Vector3(4, 0, 0)
	_tick(model, 0.9, false)
	_tick(model, 1.0, true)
	_tick(model, 0.01, false)
	_check(mine.hack_progress == 0.0, "Releasing E immediately clears progress")
	_tick(model, 1.0, true)
	model.player.position = Vector3(6, 0, 0)
	_tick(model, 0.01, true)
	_check(mine.hack_progress == 0.0, "Leaving the 4.5m hacking range immediately clears progress")
	model.player.position = Vector3(4, 0, 0)
	_tick(model, 1.0, true)
	var second: Dictionary = model.hazards.drop(model, owner)
	second.position = Vector3(0, 0, 8)
	second.arm_remaining = 0.0
	model.player.position = Vector3(4, 0, 8)
	_tick(model, 0.1, true)
	_check(mine.hack_progress == 0.0 and is_equal_approx(second.hack_progress, 0.1), "Changing the nearest target starts its own fresh hold")
	model.player.modules = model.player.modules.filter(func(module: Dictionary) -> bool: return module.type != "mineHacker")
	_tick(model, 0.1, true)
	_check(second.hack_progress == 0.0 and model.hazards.hack_status.requires_module, "Removing the installed kit cancels the hold")
	Input.action_release("interact")
	model.running = false
	game.queue_free()
	await process_frame
	paused = false
	print("Mine hacking module: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _tick(model, seconds: float, held: bool) -> void:
	if held:
		Input.action_press("interact")
	else:
		Input.action_release("interact")
	model.player.interact = Input.is_action_pressed("interact")
	var remaining := seconds
	while remaining > 0.000001:
		var delta := minf(0.1, remaining)
		model.hazards.step(model, delta)
		remaining -= delta

func _action(parent: Node, id: String) -> Button:
	if parent is Button and parent.get_meta("action_id", "") == id:
		return parent
	for child in parent.get_children():
		var found := _action(child, id)
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
