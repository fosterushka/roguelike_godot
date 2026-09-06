extends SceneTree
const Main = preload("res://app/main.tscn")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
var checks := 0
var failures := 0
func _init() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _start(game) -> void:
	game._menu_action("start" if game.screen_state == "menu" else "restart", "")
	await game.run_prepared
	for index in 60:
		game.session_flow.advance(0.05)
	check(game.screen_state == "running" and game.expedition.active, "Main starts a real active raid")
func _place(game, point: Vector3) -> void:
	game.vehicle.global_position = Vector3(point.x, Ground.height_at(point.x, point.z) + 0.4, point.z)
	game.vehicle.motion.x = point.x
	game.vehicle.motion.z = point.z
	game.vehicle.motion.speed = 0
	game.vehicle.velocity = Vector3.ZERO
	game.combat._sync_vehicle_to_model()
func _key(game, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	game._input(event)
func _run() -> void:
	var game = Main.instantiate()
	var path := "/private/tmp/caravan-integration-%d.json" % Time.get_ticks_usec()
	game.profile_path = path
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	var roster: RefCounted = game.expedition.caravan
	check(game.screen_state == "menu" and roster.data().wagons.is_empty(), "Isolated Main profile starts without free trailers")
	game.progression.profile.expedition.credits = 3000
	game._menu_action("garage", "")
	check(game.screen_state == "garage" and game.caravan_panel.visible, "Real menu action opens garage panel")
	for type: String in ["cargo", "repair", "weapon"]:
		game.caravan_panel.action_requested.emit("buy_wagon", type, "")
	var ids: Array = roster.data().selected_wagon_ids.duplicate()
	check(ids.size() == 3 and roster.data().wagons.size() == 3, "Garage panel signals buy three separate persistent wagons")
	check(Store.new(path).load_profile().expedition.caravan.wagons.size() == 3, "Garage purchases are committed to isolated disk profile")
	if ids.size() != 3:
		game.queue_free()
		await process_frame
		quit(1)
		return
	game.caravan_panel.closed.emit()
	await _start(game)
	check(roster.wagons.size() == 3 and game.combat.model.player.carriers.size() == 3, "Main departure hydrates selected wagon instances")
	check(Store.new(path).load_profile().expedition.caravan.wagons.is_empty(), "Deployed wagons removed from saved garage atomically")
	check(game.crew_runtime.recruits.size() == 7, "Main creates all seven field recruit roles")
	var mechanic: Dictionary = game.crew_runtime.recruits[0]
	_place(game, mechanic.position)
	_key(game, KEY_E)
	check(roster.crew.size() == 1 and mechanic.boarded, "Actual E input rescues and boards starter mechanic")
	var crew_id: String = mechanic.id
	_key(game, KEY_J)
	game.caravan_panel.tab = "crew"
	game.caravan_panel._refresh()
	var selectors: Array = game.caravan_panel.find_children("*", "OptionButton", true, false)
	check(selectors.size() == 1 and not selectors[0].disabled, "Live J crew menu exposes usable assignment control")
	if selectors.size() == 1:
		selectors[0].select(2)
		selectors[0].item_selected.emit(2)
		check(mechanic.carrier_id == ids[0], "Actual crew selector assigns rescued mechanic to first wagon")
		selectors = game.caravan_panel.find_children("*", "OptionButton", true, false)
		selectors[0].select(0)
		selectors[0].item_selected.emit(0)
		check(mechanic.carrier_id == "crawler", "Crew selector returns mechanic to pickup without duplicating crew")
	_key(game, KEY_J)
	game.vehicle.health -= 10
	game.combat._sync_vehicle_to_model()
	var health_before: float = game.vehicle.health
	game.session_flow.advance(0.5)
	game.combat._physics_process(0.5)
	check(game.vehicle.health > health_before, "Main support step applies real mechanic repair back to vehicle")
	game.combat.model.player.coins = 1000
	game.combat.model.player.pending_upgrades = 0
	game._toggle_armory()
	check(game.screen_state == "armory", "Main opens actual Armory during raid")
	game._menu_action("buy", "module:assaultRifle:%s:0" % ids[2])
	var modules: Array = game.combat.model.player.modules.filter(func(module): return module.get("mount", {}).get("carrierId", "") == ids[2])
	check(modules.size() == 1 and modules[0].type == "assaultRifle", "Armory purchase installs weapon on addressed tail wagon")
	game._menu_action("buy", "attachment:armor_panels:%s:1" % ids[2])
	check(roster.find_wagon(ids[2]).attachments.size() == 1, "Armory purchase installs real per-wagon attachment")
	game._resume()
	check(game.expedition.collect_loot("scrap", 20), "Raid cargo fills pickup and cargo wagon")
	var tail: Dictionary = roster.find_wagon(ids[2])
	check(game.caravan.damage_target(ids[1], 99999, "test_explosion"), "Real caravan damage route destroys middle wagon")
	check(roster.find_wagon(ids[1]).dead and not tail.attached, "Middle destruction leaves surviving tail detached")
	check(modules.size() == 1 and modules[0].get("disabled", false), "Detached wagon weapon immediately disabled in player build")
	check(game.combat.model.weapons.filter(func(module): return module.get("mount", {}).get("carrierId", "") == ids[2]).size() == 1, "Disabled weapon retains its identity for recoupling")
	_place(game, tail.position)
	_key(game, KEY_E)
	game.caravan.step(0.01)
	check(tail.attached and not modules[0].get("disabled", true), "Actual E recouples tail and restores existing weapon")
	var site: Dictionary = game.world.activities.get_extraction_state().sites[0]
	_place(game, site.position)
	_key(game, KEY_E)
	check(game.world.activities.get_extraction_state().active, "Actual E starts extraction with attached convoy")
	for index in 410:
		if game.screen_state != "running":
			break
		game.session_flow.advance(0.05)
		game.world.activities._update_extraction(0.05)
	check(game.screen_state == "result" and game.expedition.last_result.get("success", false), "Extraction defense completion reaches actual Main result")
	var saved: Dictionary = Store.new(path).load_profile()
	check(saved.expedition.caravan.wagons.size() == 2 and not saved.expedition.caravan.wagons.has(ids[1]), "Result persists attached survivors and permanently removes destroyed wagon")
	check(saved.expedition.caravan.crew.has(crew_id), "Boarded living mechanic saved under persistent ID")
	check(saved.expedition.stash.get("scrap", 0) == 20, "Whole convoy cargo deposited exactly once")
	check(saved.expedition.caravan.wagons[ids[2]].modules.size() == 1 and saved.expedition.caravan.wagons[ids[2]].attachments.size() == 1, "Wagon weapon and attachment survive result save")
	check(game.expedition.last_result.caravan.wagons_returned.size() == 2 and game.expedition.last_result.caravan.wagons_lost.size() == 1, "Result manifest reports returned and lost wagon counts")
	check("2" in game._expedition_result_text() and "1" in game._expedition_result_text(), "Actual result summary includes returned and lost convoy counts")
	check(not game.expedition.finish_run(true) and Store.new(path).load_profile().expedition.stash.scrap == 20, "Repeated result cannot duplicate stash or survivors")
	await _start(game)
	check(roster.crew.size() == 1 and roster.crew[0].id == crew_id and roster.wagons.size() == 2, "Second Main raid restores same crew and surviving wagon IDs")
	check(game.progression.profile.expedition.stash.scrap == 18 and Store.new(path).load_profile().expedition.stash.scrap == 18, "Second departure charges exact mechanic wage once on disk")
	var restored: Array = game.combat.model.player.modules.filter(func(module): return module.get("mount", {}).get("carrierId", "") == ids[2])
	check(restored.size() == 1 and game.combat.model.weapons.filter(func(module): return module.get("mount", {}).get("carrierId", "") == ids[2]).size() == 1, "Main hydration restores wagon weapon once in modules and combat weapons")
	check(not game.expedition.begin_run(game.combat.model.player) and game.progression.profile.expedition.stash.scrap == 18, "Repeated departure cannot charge wage twice")
	game.combat.finish_run(false, "integration_test")
	for index in 70:
		game.session_flow.advance(0.05)
	game.combat._publish()
	check(not game.expedition.active and Store.new(path).load_profile().expedition.caravan.wagons.is_empty(), "Failed second raid permanently loses deployed surviving wagons")
	check(Store.new(path).load_profile().expedition.caravan.crew.is_empty(), "Failed raid loses deployed crew without returning or refunding wage")
	game.queue_free()
	await process_frame
	paused = false
	print("Caravan integration tests: %d/%d" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
