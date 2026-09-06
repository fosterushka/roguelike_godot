extends SceneTree
const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	Locale.settings_path = "/private/tmp/trailer-ui-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/trailer-ui-profile-%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await game.game_ready
	game.caravan_flow.open_trailers()
	var panel = game.caravan_panel
	check(panel.tab == "wagons" and _tab(panel, "shop") != null, "First-time owner has a visible BUY TRAILER entry")
	_tab(panel, "shop").pressed.emit()
	game.progression.profile.expedition.credits = 0
	game.caravan_flow.refresh()
	check(_action(panel, "buy_wagon:cargo").disabled and _action(panel, "buy_wagon:cargo").text.contains("180"), "Unaffordable trailer states the missing credit amount")
	game.progression.profile.expedition.credits = 1000
	game.caravan_flow.refresh()
	_action(panel, "buy_wagon:cargo").pressed.emit()
	var roster = game.expedition.caravan
	var id: String = roster.data().selected_wagon_ids[0]
	check(roster.data().wagons.size() == 1 and game.progression.profile.expedition.credits == 820, "BUY & ATTACH charges exactly once and owns a trailer")
	check(panel.tab == "equipment" and panel.equipment_wagon_id == id and not panel.purchase_notice.is_empty(), "Purchase opens exact trailer equipment with attached confirmation")
	check(_action(panel, "install_attachment:attachment:cargo_rack:%s:0" % id) != null, "Empty mount receives clearly priced equipment action")
	_action(panel, "install_attachment:attachment:cargo_rack:%s:0" % id).pressed.emit()
	check(roster.data().wagons[id].attachments == [{"type": "cargo_rack", "slot": 0}] and game.progression.profile.expedition.credits == 730, "Base equipment purchase persists on correct trailer and charges credits")
	check(_action(panel, "install_attachment:attachment:cargo_rack:%s:1" % id).disabled, "Installed equipment cannot be bought twice")
	_action(panel, "remove_attachment:%s:0" % id).pressed.emit()
	check(roster.data().wagons[id].attachments.is_empty() and game.progression.profile.expedition.credits == 775, "Explicit REMOVE refunds half price and frees mount")
	panel.tab = "wagons"
	game.caravan_flow.refresh()
	_action(panel, "select_wagon:%s:0" % id).pressed.emit()
	check(not roster.data().selected_wagon_ids.has(id) and roster.data().wagons.has(id), "DETACH leaves purchased trailer safely at base")
	_action(panel, "configure_wagon:" + id).pressed.emit()
	_action(panel, "install_attachment:attachment:armor_panels:%s:0" % id).pressed.emit()
	check(roster.data().wagons[id].attachments.size() == 1, "Detached base trailer can still be equipped")
	panel.tab = "wagons"
	game.caravan_flow.refresh()
	_action(panel, "select_wagon:%s:1" % id).pressed.emit()
	check(roster.data().selected_wagon_ids.has(id), "ATTACH TO PICKUP restores saved trailer for next raid")
	game.caravan_flow.close()
	await game.restart_run()
	game.combat.model.player.pending_upgrades = 0
	game._toggle_armory()
	game.hud.armory.trailers_button.pressed.emit()
	check(game.screen_state == "garage", "Armory TRAILERS button opens convoy management")
	panel.tab = "shop"
	game.caravan_flow.refresh()
	check(_action(panel, "buy_wagon:cargo").disabled and _action(panel, "buy_wagon:cargo").text.contains("BASE"), "Raid shop explicitly directs purchases to base")
	panel.tab = "wagons"
	game.caravan_flow.refresh()
	_action(panel, "configure_wagon:" + id).pressed.emit()
	check(game.screen_state == "armory" and game.hud.armory.mount_selector.selected_carrier() == id, "EQUIP TRAILER opens exact named trailer in raid Armory")
	check(not game.hud.armory.mount_selector.carrier.get_item_text(1).contains("wagon-"), "Carrier selector exposes trailer name rather than internal ID")
	game.queue_free()
	await process_frame
	paused = false
	print("Trailer UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _action(node: Node, id: String) -> Button:
	if node is Button and node.get_meta("caravan_action", "") == id:
		return node
	for child in node.get_children():
		var found := _action(child, id)
		if found != null:
			return found
	return null
func _tab(node: Node, id: String) -> Button:
	if node is Button and node.get_meta("caravan_tab", "") == id:
		return node
	for child in node.get_children():
		var found := _tab(child, id)
		if found != null:
			return found
	return null
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
