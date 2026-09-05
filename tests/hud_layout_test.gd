extends SceneTree

const Hud = preload("res://presentation/ui/hud.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0
var actions: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-hud-layout-%d.cfg" % Time.get_ticks_usec()
	var hud := Hud.new()
	root.add_child(hud)
	hud.set_loading(false)
	hud.set_gameplay_active(true)
	var player := {"hp": 80.0, "max_hp": 100.0, "coins": 30, "has_bumper": true}
	var state := {"player": player, "wave": 2, "final_wave": 6, "remaining": 7, "level": 3, "xp": 14, "xp_next": 100, "scrap": 30, "kills": 4, "elapsed": 61}
	hud.update_run(state, null, 0)
	hud.update_telemetry({"health": 80, "max_health": 100, "fuel": 65, "max_fuel": 100, "speed": 10.0})
	hud.ability_selected.connect(func(index: int) -> void: actions.append("select:%d" % index))
	hud.ability_requested.connect(func() -> void: actions.append("activate"))
	hud.get_node("Screen").set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for dimensions in [Vector2(960, 600), Vector2(1280, 800), Vector2(1920, 1080)]:
		hud.get_node("Screen").size = dimensions
		await process_frame
		await process_frame
		var stats: Rect2 = hud._stats_panel.get_global_rect()
		var hotbar: Rect2 = hud._hotbar.get_global_rect()
		var map: Rect2 = hud.radar.get_global_rect()
		_check(stats.position.x == 12 and absf(stats.end.y - (dimensions.y - 12)) < 1, "Player stats stay bottom-left at " + str(dimensions))
		_check(hotbar.size.x <= 340 and hotbar.size.y <= 56 and absf(hotbar.get_center().x - dimensions.x / 2) < 1, "Three ability slots remain compact and centered at " + str(dimensions))
		_check(not stats.intersects(hotbar) and not hotbar.intersects(map) and not stats.intersects(map), "Stats, ability slots and minimap do not overlap at " + str(dimensions))
		_check(map.end.x <= dimensions.x and map.end.y <= dimensions.y and stats.end.x < dimensions.x, "Bottom UI fits viewport at " + str(dimensions))
	_check(hud._hotbar.get_child_count() == 3 and hud._hotbar_buttons.size() == 3, "Hotbar has exactly three direct action slots without an Activate column")
	_check(hud._health_label.get_global_position().y < hud._fuel_label.get_global_position().y and hud._fuel_label.get_global_position().y < hud._speed_label.get_global_position().y and hud._speed_label.get_global_position().y < hud._coins_label.get_global_position().y, "Hull, fuel, speed and scrap form a vertical stats stack")
	_check(hud._run_label.text == "WAVE 2/6 · HOSTILES 7" and not hud._run_label.text.contains("XP"), "Top status contains only wave and enemies")
	_check(hud._coins_label.text == "SCRAP 30" and hud._player_stats_label.text.contains("LEVEL 3"), "Currency and player progression live in bottom-left stats")
	_click(hud._hotbar_buttons[1].get_global_rect().get_center())
	_check(actions == ["select:1", "activate"], "One slot click selects that ability before requesting activation")
	actions.clear()
	player.ram_cooldown = 4.0
	hud.update_run(state, null, 1)
	_check(hud._hotbar_buttons[1].disabled and hud._hotbar_buttons[1].status == "4.0s" and is_equal_approx(hud._hotbar_buttons[1].cooldown_ratio, 0.5), "Cooldown disables the action and shows remaining time and progress")
	_click(hud._hotbar_buttons[1].get_global_rect().get_center())
	_check(actions.is_empty(), "A cooling-down ability cannot be triggered by pointer")
	player.has_bumper = false
	player.ram_cooldown = 0.0
	player.hp = 100.0
	hud.update_run(state, null, 0)
	_check(hud._hotbar_buttons[1].disabled and hud._hotbar_buttons[2].disabled, "Missing ram module and full hull disable unavailable actions")
	player.hp = 70.0
	player.coins = 14
	hud.update_run(state, null, 0)
	_check(hud._hotbar_buttons[2].disabled and hud._hotbar_buttons[2].status == "15 SCRAP", "Repair clearly shows the scrap requirement")
	player.coins = 15
	hud.update_run(state, null, 0)
	_check(not hud._hotbar_buttons[2].disabled and hud._hotbar_buttons[2].status == "READY", "Repair becomes ready with damaged hull and enough scrap")
	hud.set_paused(true)
	_click(hud._hotbar_buttons[0].get_global_rect().get_center())
	_check(actions.is_empty() and not hud._stats_panel.is_visible_in_tree(), "Pause blocks compact action slots and stats controls")
	hud.set_language("ru")
	hud.update_run(state, null, 0)
	_check(hud._run_label.text == "ВОЛНА 2/6 · ВРАГИ 7" and hud._coins_label.text == "ЛОМ 30", "New compact stats and wave text support Russian")
	hud.queue_free()
	await process_frame
	DirAccess.remove_absolute(Locale.settings_path)
	print("HUD layout: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

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
