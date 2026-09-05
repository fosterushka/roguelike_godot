extends SceneTree

const Main = preload("res://app/main.tscn")
const Preparation = preload("res://infrastructure/loading/game_preparation.gd")
const UpgradeProjection = preload("res://presentation/ui/upgrade_projection.gd")
var checks := 0
var failures := 0
var progress: Array[float] = [0.0]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron_ui_test_%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	game.hud.loading_progress_changed.connect(func(value: float, _stage: String) -> void: progress.append(value))
	await game.game_ready
	var monotonic := true
	for index in range(1, progress.size()):
		monotonic = monotonic and progress[index] >= progress[index - 1]
	_check(monotonic and progress.size() > 40 and progress[-1] == 1.0, "Real loading work reports monotonic resource/model progress before ready")
	_check(game.combat.model.elapsed == 0 and paused, "Asynchronous loading batches keep simulation frozen")
	await game.restart_run()
	game.combat.model.player.coins = 1000
	game.hud.show_world_banner("ВОЛНА 1", "Собирайте лом и развивайте арсенал")
	var banner_time: float = game.hud._banner_remaining
	game._toggle_armory()
	game.hud._process(0.5)
	_check(not game.hud._world_banner.visible and game.hud._banner_remaining == banner_time, "Armory hides gameplay banner and preserves its remaining time")
	var panel = game.hud.armory
	_check(panel.visible and panel.close_button.get_global_rect().position.y < 100, "Armory close remains pinned above the scrolling catalog")
	_check(panel.preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and panel.preview.assembly.get_child_count() > 0, "Armory displays real prepared3D assembly")
	panel.filter.selected = 1
	panel.rebuild_cards()
	var only_weapons := true
	for type: String in panel.matching_types():
		only_weapons = only_weapons and panel._catalog.modules[type].has("projectile")
	_check(only_weapons and panel.matching_types().size() == 7, "Source weapons filter exposes all seven weapon definitions")
	panel.filter.selected = 3
	panel.rebuild_cards()
	_check(panel.matching_types() == ["assaultRifle"], "Installed filter reflects live build")
	panel.filter.selected = 0
	panel.query.text = "accurate rifle"
	panel.rebuild_cards()
	_check(panel.matching_types() == ["assaultRifle"], "Search requires every source query term across name/description")
	panel.query.text = ""
	panel.rebuild_cards()
	var bazooka: Button = _action(panel, "module:bazooka")
	_check(bazooka != null and not bazooka.disabled, "Affordable unlocked weapon exposes enabled purchase control")
	var before: int = game.combat.model.player.coins
	bazooka.pressed.emit()
	_check(game.combat.model.weapons.size() == 2 and game.combat.model.player.coins < before and paused, "Actual armory purchase button equips weapon without resuming combat")
	var remove: Button = _action(panel, "remove:1")
	before = game.combat.model.player.coins
	remove.pressed.emit()
	_check(game.combat.model.weapons.size() == 1 and game.combat.model.player.coins > before, "Refund control removes actual weapon and credits source refund")
	var generation: int = game.combat.model.generation
	panel.query.grab_focus()
	_key(KEY_R)
	_check(game.combat.model.generation == generation and game.screen_state == "armory", "Typing R in module search does not restart the run")
	_key(KEY_ESCAPE)
	_check(game.screen_state == "running" and not panel.visible and panel.preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Escape closes armory and suspends hidden preview rendering")
	_check(game.hud._world_banner.visible and game.hud._banner_remaining == banner_time, "Closing armory restores gameplay banner without consuming its timer")
	game.hud.show_menu("MENU", "", [])
	game.hud._process(0.5)
	_check(not game.hud._world_banner.visible and game.hud._banner_remaining == banner_time, "Menu blocks gameplay banner even before a simulation pause")
	game.hud.hide_menus()
	var touch = game.hud.touch_controls
	touch.visible = true
	await process_frame
	for sample in [{"index": 1, "action": "drive_forward"}, {"index": 2, "action": "drive_left"}]:
		for button: Button in touch._buttons:
			if button.get_meta("touch_action", "") == sample.action:
				var finger := InputEventScreenTouch.new()
				finger.index = sample.index
				finger.position = button.get_global_rect().get_center()
				finger.pressed = true
				touch._input(finger)
	_check(Input.is_action_pressed("drive_forward") and Input.is_action_pressed("drive_left"), "Two touch pointers can steer and accelerate simultaneously")
	touch._release_touch(1)
	_check(not Input.is_action_pressed("drive_forward") and Input.is_action_pressed("drive_left"), "Releasing one pointer preserves the other touch action")
	touch.release_all()
	game.hud.touch_controls.press("drive_forward")
	_check(Input.is_action_pressed("drive_forward"), "Virtual drive control shares the real input action")
	game.hud.show_world_banner("ВОЛНА", "ПРОВЕРКА")
	banner_time = game.hud._banner_remaining
	game._toggle_pause()
	game.hud._process(0.5)
	_check(not game.hud._world_banner.visible and game.hud._banner_remaining == banner_time, "Pause hides gameplay banner without advancing its timer")
	_check(not Input.is_action_pressed("drive_forward"), "Pausing releases held touch input")
	game.hud.touch_controls.press("drive_forward")
	_check(not Input.is_action_pressed("drive_forward"), "Blocked touch controls cannot reapply throttle")
	game._resume()
	game.camera._intro = 0
	game.combat.model.enemies.clear()
	var enemy: Dictionary = game.combat.model.spawn_enemy("rifleman", Vector3(8, 0, 8))
	var point: Vector2 = game.camera.unproject_position(enemy.position + Vector3.UP * 2.0)
	game.combat.model.focus_id = -1
	game._pointer(point, true, -1, 24)
	_check(game.combat.model.focus_id == -1, "Pointer press alone does not select a target")
	game._pointer(point + Vector2(20, 0), false, -1, 24)
	_check(game.combat.model.focus_id == -1, "A drag beyond source8pixel threshold does not select")
	game._pointer(point, true, -1, 24)
	game._pointer(point, false, -1, 24)
	_check(game.combat.model.focus_id == enemy.id, "Released click selects actual target through camera projection")
	game.combat.buy_upgrade("module:radar")
	var radar = game.hud.radar
	_check(radar.ZOOMS == [0.6, 0.8, 1.0, 1.35, 1.8] and radar.zoom_index == 4 and radar.zoom_label() == "100%", "Radar preserves all five source zooms and100percent default")
	_check(radar.visible and radar.effective_range == 40 and radar.explored(Vector3.ZERO), "Installed radar reveals local cells and starts with40mrange")
	game.combat.model.spawn_enemy("jammerTruck", Vector3(20, 0, 0))
	game.combat._publish()
	_check(radar.jammed and is_equal_approx(radar.effective_range, 22.0), "Living nearby jammer applies source0.55radar multiplier")
	var previous_hp: float = game.combat.model.player.max_hp
	var preview := UpgradeProjection.description("core:armor", game.combat.model.player, game.combat.model.weapons)
	_check(preview.contains("250.00 → 295.00") and game.combat.model.player.max_hp == previous_hp, "Choice comparison previews actual core rule without mutating player")
	await game.restart_run()
	_check(game.hud.radar.zoom_index == 4 and game.hud.radar.visible and game.hud.radar.effective_range == 18, "Restart resets radar upgrade but keeps basic map visible")
	game.queue_free()
	await process_frame
	paused = false
	await _invalid_json_test()
	print("UI flow: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _invalid_json_test() -> void:
	var path := "/private/tmp/iron-ui-bad-%d.json" % Time.get_ticks_usec()
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{invalid")
	bad.close()
	var manifest := FileAccess.open(path + ".manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"resources": [], "data": [path]}))
	manifest.close()
	var loader := Preparation.new()
	loader.manifest_path = path + ".manifest.json"
	var success: bool = await loader.validate_and_load(root, func(_stage: String, _value: float) -> void: pass)
	_check(not success and loader.errors.size() == 1 and loader.errors[0].contains(path), "Malformed JSON stops loading with original file/error details")

func _action(parent: Node, id: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.get_meta("action_id", "") == id:
			return child
		var found := _action(child, id)
		if found != null:
			return found
	return null

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
