extends SceneTree

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-armory-tiles-language-%d.cfg" % Time.get_ticks_usec()
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-armory-tiles-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.combat.model.player.coins = 1000
	game.combat.model.player.level = 4
	game._toggle_armory()
	var panel = game.hud.armory
	await process_frame
	await process_frame
	_check(panel.cards.get_child_count() == panel._catalog.modules.size() and panel.cards.columns >= 2, "Armory exposes all modules as a tile grid; wagons are purchased in the hideout")
	_check(panel.preview.size.x >= 350 and panel.preview.size.y >= 156 and panel.preview.size.y <= 230, "Vehicle inspection leaves room for visible statistics")
	var tile: Control = panel._tile_panels.bazooka
	_check(tile.size.y < 180 and tile.size.x < 360, "Uninstalled module is a compact tile instead of a description row")
	var inspect: Button = tile.find_child("Inspect", true, false)
	_click(inspect.get_global_rect().get_center())
	_check(panel._selected == "bazooka" and panel.details.text.contains("Bazooka Pod") and is_instance_valid(panel.preview.selected), "Actual tile click selects the module and its 3D inspection model")
	var preview = panel.preview
	var start: Vector2 = preview.get_global_rect().get_center()
	var yaw_before: float = preview.yaw
	var camera_before: Vector3 = preview.camera.position
	_mouse(MOUSE_BUTTON_LEFT, start, true)
	var drag := InputEventMouseMotion.new()
	drag.position = start + Vector2(70, -30)
	drag.relative = Vector2(70, -30)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(drag, true)
	_mouse(MOUSE_BUTTON_LEFT, drag.position, false)
	_check(not is_equal_approx(preview.yaw, yaw_before) and not preview.camera.position.is_equal_approx(camera_before), "Viewport drag rotates the inspection camera")
	var size_before: float = preview.camera.size
	_mouse(MOUSE_BUTTON_WHEEL_UP, start, true)
	_mouse(MOUSE_BUTTON_WHEEL_UP, start, false)
	_check(preview.camera.size < size_before and preview.zoom > 1.0, "Mouse wheel zooms in on the vehicle")
	_click(panel.reset_view_button.get_global_rect().get_center())
	_check(is_equal_approx(preview.yaw, 0.75) and is_equal_approx(preview.pitch, 0.52) and is_equal_approx(preview.zoom, 1.0), "Reset view button restores the inspection camera")
	_check(_action(panel, "trailer") == null, "Raid armory has no obsolete trailer purchase action")
	game.combat.model.player.carriers.append(preload("res://modules/caravan/wagon_factory.gd").create("cargo", "wagon-test"))
	game._show_armory()
	_check(panel.mount_selector.carrier.item_count == 2, "Owned wagon appears as an individual selectable carrier")
	var selector = panel.mount_selector
	selector.carrier.select(1)
	selector.carrier.item_selected.emit(1)
	selector.slot.select(1)
	selector.slot.item_selected.emit(1)
	panel.select_module("bazooka")
	_check(preview.selected.get_meta("mount") == {"carrierId": "wagon-test", "slot": 1} and preview.selected.position == preload("res://presentation/vehicles/vehicle_view.gd").TRAILER_SLOTS[1], "Chosen wagon mount previews equipment in local coordinates")
	var purchase: Button = _action(panel, "module:bazooka")
	panel._catalog_scroll.ensure_control_visible(purchase)
	await process_frame
	var money_before: int = game.combat.model.player.coins
	_click(purchase.get_global_rect().get_center())
	var mounted: Array = game.combat.model.player.modules.filter(func(module: Dictionary) -> bool: return module.type == "bazooka")
	_check(mounted.size() == 1 and mounted[0].mount == {"carrierId": "wagon-test", "slot": 1} and game.combat.model.player.coins < money_before, "Actual tile purchase equips the weapon on the selected trailer slot and charges scrap")
	_check(selector.selected_mount().get("carrierId") == "wagon-test" and selector.slot.is_item_disabled(1), "Refresh preserves carrier selection and disables the occupied mount")
	panel.query.text = "bazooka"
	panel.rebuild_cards()
	_check(panel.cards.get_child_count() == 1, "Tile search keeps matching catalog behavior")
	panel.query.text = ""
	panel.rebuild_cards()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for dimensions in [Vector2(960, 540), Vector2(1280, 720)]:
		panel.size = dimensions
		await process_frame
		await process_frame
		_check(panel.preview.get_global_rect().end.x < panel._catalog_scroll.get_global_rect().position.x and panel.save_status.get_global_rect().end.y <= dimensions.y, "Preview, catalog and footer fit " + str(dimensions))
	preview.set_active(false)
	yaw_before = preview.yaw
	preview._gui_input(drag)
	_check(preview.yaw == yaw_before and preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden preview ignores drag and stops rendering")
	game.queue_free()
	await process_frame
	paused = false
	print("Armory tiles: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _action(parent: Node, id: String) -> Button:
	if parent is Button and parent.get_meta("action_id", "") == id:
		return parent
	for child in parent.get_children():
		var found := _action(child, id)
		if found != null:
			return found
	return null

func _click(point: Vector2) -> void:
	_mouse(MOUSE_BUTTON_LEFT, point, true)
	_mouse(MOUSE_BUTTON_LEFT, point, false)

func _mouse(button: MouseButton, point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
