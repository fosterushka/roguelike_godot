extends SceneTree

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-radar-armory-language-%d.cfg" % Time.get_ticks_usec()
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-radar-armory-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.combat.model.player.coins = 1000
	game._toggle_armory()
	var panel = game.hud.armory
	await process_frame
	_check(_action(panel, "radar:2") == null and _action(panel, "module:radar") != null, "Uninstalled radar exposes installation rather than an upgrade")
	var install: Button = _action(panel, "module:radar")
	panel._catalog_scroll.ensure_control_visible(install)
	await process_frame
	var coins: int = game.combat.model.player.coins
	_click(install.get_global_rect().get_center())
	_check(_radar(game).get("level") == 1 and game.combat.model.player.radar_range == 40.0 and game.combat.model.player.coins == coins - 55, "Actual radar tile installation charges 55 scrap and starts at MK1 with 40m range")
	panel.select_module("radar")
	_check(panel.details.text.contains("MK level 1") and panel.details.text.contains("Range: 40.00"), "Radar details show installed level and actual range")
	_check(_action(panel, "module:radar") == null and _action(panel, "radar:2") != null, "Installed radar tile replaces install control with its level upgrade")
	game.combat.model.player.coins = 1
	game._show_armory()
	var unaffordable: Button = _action(panel, "radar:2")
	_check(unaffordable.disabled and unaffordable.tooltip_text.contains("45"), "Unaffordable radar upgrade is disabled with the required cost")
	panel._catalog_scroll.ensure_control_visible(unaffordable)
	await process_frame
	_click(unaffordable.get_global_rect().get_center())
	_check(_radar(game).level == 1 and game.combat.model.player.coins == 1, "Clicking a disabled upgrade leaves level and money unchanged")
	game.combat.model.player.coins = 1000
	game._show_armory()
	panel.filter.selected = 3
	panel.rebuild_cards()
	for expected in [{"level": 2, "range": 90.0, "cost": 45}, {"level": 3, "range": 160.0, "cost": 70}, {"level": 4, "range": 260.0, "cost": 100}]:
		var upgrade: Button = _action(panel, "radar:%d" % expected.level)
		_check(upgrade != null and not upgrade.disabled, "Installed filter exposes radar upgrade to MK%d" % expected.level)
		panel._catalog_scroll.ensure_control_visible(upgrade)
		await process_frame
		coins = game.combat.model.player.coins
		_click(upgrade.get_global_rect().get_center())
		_check(_radar(game).level == expected.level and _radar(game).def.range == expected.range and game.combat.model.player.radar_range == expected.range and game.combat.model.player.coins == coins - expected.cost, "Actual upgrade click changes module, player range and money for MK%d" % expected.level)
		_check(panel.details.text.contains("MK level %d" % expected.level) and panel.details.text.contains("Range: %.2f" % expected.range), "Selected radar details refresh after upgrading to MK%d" % expected.level)
	var capped: Button = _action(panel, "radar:4")
	_check(capped != null and capped.disabled and capped.text == "MAX LEVEL", "Maximum radar level remains visible as a disabled capped control")
	coins = game.combat.model.player.coins
	panel._catalog_scroll.ensure_control_visible(capped)
	await process_frame
	_click(capped.get_global_rect().get_center())
	_check(_radar(game).level == 4 and game.combat.model.player.coins == coins, "Capped control cannot charge scrap or exceed MK4")
	game.queue_free()
	await process_frame
	paused = false
	print("Radar armory: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _radar(game: Node) -> Dictionary:
	for module: Dictionary in game.combat.model.player.modules:
		if module.type == "radar":
			return module
	return {}

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
