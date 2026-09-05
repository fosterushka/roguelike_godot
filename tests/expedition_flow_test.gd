extends SceneTree

const Main = preload("res://app/main.tscn")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _button(node: Node, metadata: String, value: String) -> Button:
	if node is Button and node.get_meta(metadata, "") == value:
		return node
	for child: Node in node.get_children():
		var found := _button(child, metadata, value)
		if found != null:
			return found
	return null

func _press(node: Node, metadata: String, value: String) -> void:
	var button := _button(node, metadata, value)
	check(button != null and not button.disabled, "Available UI action: " + value)
	if button != null and not button.disabled:
		button.pressed.emit()

func _tab(panel, id: String) -> void:
	var names := {"stash": ["СКЛАД", "VAULT"], "trade": ["ТОРГОВЕЦ", "TRADER"], "quests": ["ЗАДАНИЯ", "TASKS"], "upgrades": ["ПРОКАЧКА", "UPGRADES"]}
	for button: Button in panel.tabs.get_children():
		if button.text in names[id]:
			if not button.disabled:
				button.pressed.emit()
			return
	check(false, "Missing actual tab button: " + id)

func _key(game, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	game._input(event)

func _start(game, action: String) -> void:
	_press(game.hud.run_menu, "action_id", action)
	await game.run_prepared
	for index in 60:
		game.session_flow.advance(0.05)
	check(game.screen_state == "running" and game.expedition.active, "Prepared raid becomes playable with active backpack")

func _pick_crates(game, point: Vector3) -> void:
	game.vehicle.global_position = point
	game.combat.model.player.position = point
	game._physics_process(0.21)

func _settle_camera(game) -> void:
	for index in 150:
		game.camera._process(0.02)

func _run() -> void:
	var game = Main.instantiate()
	var path := "/private/tmp/iron-expedition-flow-%d.json" % Time.get_ticks_usec()
	game.profile_path = path
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.camera.set_process(false)
	check(game.screen_state == "menu" and paused, "Boot exposes a paused main menu")
	_press(game.hud.run_menu, "action_id", "hideout")
	check(game.screen_state == "expedition" and game.expedition_panel.visible, "Menu opens the actual hideout panel")
	var panel = game.expedition_panel
	_tab(panel, "trade")
	_press(panel, "expedition_action", "buy:repair_kit")
	check(game.expedition.snapshot().credits == 240 and game.expedition.snapshot().stash.repair_kit == 3, "Trader purchase charges account credits and stores the purchased kit")
	_tab(panel, "stash")
	_press(panel, "expedition_action", "equip:repair_kit")
	check(game.expedition.snapshot().loadout.repair_kit == 1 and game.expedition.snapshot().stash.repair_kit == 2, "Pack button moves a real item out of the vault")
	_tab(panel, "quests")
	_press(panel, "expedition_action", "accept:first_delivery")
	check(game.progression.profile.expedition.quests.first_delivery.status == "active", "Task button accepts the delivery contract")
	_tab(panel, "upgrades")
	_press(panel, "expedition_action", "upgrade:armor")
	check(game.expedition.snapshot().credits == 40, "Permanent armor upgrade uses account credits")
	_key(game, KEY_ESCAPE)
	check(game.screen_state == "menu" and paused, "Hideout Escape restores the start menu")
	await _start(game, "start")
	var model = game.combat.model
	check(game.expedition.backpack.get("repair_kit", 0) == 1 and game.expedition.snapshot().loadout.is_empty(), "Starting consumes saved loadout into raid backpack")
	check(model.player.max_hp == 270.0 and game.vehicle.max_health == 270.0, "Permanent armor applies to both combat and live vehicle")
	var loaded: Dictionary = Store.new(path).load_profile()
	check(loaded.expedition.loadout.is_empty(), "Loadout removal reaches disk before combat begins")
	var fury = game.hud.fury_meter
	model.road_fury.record(0.2)
	model.road_fury.step(model.player, 0.01)
	fury.update_player(model.player)
	check(is_equal_approx(fury.meter.value, 20.0) and ("КОМБО" in fury.caption.text or "COMBO" in fury.caption.text), "Driving meter displays actual combo charge and driving prompt")
	for index in 6:
		model.road_fury.record(0.2)
	model.step(0.01)
	game.combat._publish()
	check(model.player.road_fury_overdrive == 5.0 and fury.meter.value == 100.0 and "5.0" in fury.caption.text, "Real full combo starts overdrive and live HUD shows its five-second duration")
	for index in 51:
		model._tick_abilities(0.1)
		model.road_fury.step(model.player, 0.1)
	fury.update_player(model.player)
	check(model.player.road_fury_overdrive == 0.0 and fury.meter.value > 0.0 and fury.meter.value < 5.0 and ("ВОССТАНОВЛЕНИЕ" in fury.caption.text or "RECOVERING" in fury.caption.text), "Expired overdrive meter shows real recovery countdown and refill progress")
	model.road_fury.reset()
	model.road_fury.step(model.player, 0.01)
	_settle_camera(game)
	var landmark: Vector3 = game.vehicle.global_position + Vector3(5, 0, 8)
	var before_hit: Vector2 = game.camera.unproject_position(landmark)
	model.damage_player(100)
	game.combat._sync_model_to_vehicle()
	game.combat._publish()
	check(game.camera.shake > 0.0, "Actual player damage reaches the follow camera")
	game.camera._process(0.02)
	check(game.camera.unproject_position(landmark).distance_to(before_hit) > 0.5, "Hit visibly displaces a projected world landmark")
	_settle_camera(game)
	check(game.camera.shake == 0.0 and absf(game.camera.h_offset) < 0.001 and absf(game.camera.v_offset) < 0.001, "Hit offsets decay fully after settling")
	var before_blast: Vector2 = game.camera.unproject_position(landmark)
	model._explode({"position": model.player.position + Vector3(8, 0, 0), "kind": "grenade", "team": "enemy", "damage": 1.0})
	game.combat._publish()
	check(game.camera.shake > 0.0, "Nearby real explosion reaches camera through combat presentation")
	game.camera._process(0.02)
	check(game.camera.unproject_position(landmark).distance_to(before_blast) > 0.5, "Explosion displaces the projected world without needing player damage")
	_settle_camera(game)
	check(game.camera.shake == 0.0, "Explosion shake decays")
	game.session_flow.clock.hit_stop = 0.0
	_key(game, KEY_I)
	check(paused and game.screen_state == "expedition", "Inventory shortcut pauses live combat")
	var hp_before: float = model.player.hp
	_press(panel, "expedition_action", "consume:repair_kit")
	check(model.player.hp == minf(model.player.max_hp, hp_before + 90.0) and game.vehicle.health == model.player.hp and not game.expedition.backpack.has("repair_kit"), "Using carried kit heals actual vehicle and consumes exactly one item")
	_key(game, KEY_ESCAPE)
	check(not paused and game.screen_state == "running", "Inventory Escape resumes an active raid")
	game._toggle_pause()
	_key(game, KEY_I)
	check(game.screen_state == "expedition" and paused, "Inventory also opens from pause")
	_key(game, KEY_ESCAPE)
	check(game.screen_state == "pause" and paused, "Closing inventory opened from pause preserves pause")
	game._resume()
	for index in 7:
		model.spawn_pickup(model.player.position, 1)
	model._update_pickups(0.0)
	game.combat._publish()
	check(game.expedition.backpack.get("scrap", 0) == 6 and game.expedition.backpack.get("circuit", 0) == 1, "Seven physical salvage pickups reach inventory through actual combat event hook")
	check(game.progression.profile.expedition.quests.first_delivery.progress == 0, "Delivery progress remains unbanked before extraction")
	var convoy: Dictionary = game.world.activities.announce("raiderSupplyConvoy", {"position": Vector3(400, 0, 0)})
	game.world.activities.finish(convoy, "completed")
	game.combat._publish()
	check(game.raid_loot.crates.size() == 1 and game.raid_loot.crates[0].source == "convoy" and game.raid_loot.crates[0].count == 2, "Real convoy completion spawns physical weapon cargo with source and quantity")
	game._on_world_state({})
	var cargo_hints: Array = game.hud.markers.edge_candidates().filter(func(hint: Dictionary) -> bool: return hint.id == "raid_loot")
	check(cargo_hints.size() == 1 and is_equal_approx(cargo_hints[0].position.x, 400.0), "Real distant cargo is injected into world HUD and gets an offscreen loot direction marker")
	_pick_crates(game, Vector3(400, 0, 0))
	check(game.raid_loot.crates.is_empty() and game.expedition.backpack.get("weapon_parts", 0) == 2, "Driving to convoy crate collects two weapon kits via main polling")
	var fortress: Dictionary = game.world.foundries.foundries[0]
	model.kill_enemy(fortress.enemy)
	game.world.foundries.step(0.0)
	game.combat._publish()
	_pick_crates(game, fortress.enemy.position)
	check(game.raid_loot.crates.size() == 1 and not game.expedition.backpack.has("relic"), "Full backpack leaves a two-slot relic safely in the world")
	_key(game, KEY_I)
	_press(panel, "expedition_action", "discard:circuit")
	_key(game, KEY_ESCAPE)
	_pick_crates(game, fortress.enemy.position)
	check(game.raid_loot.crates.is_empty() and game.expedition.backpack.get("relic", 0) == 1, "Freeing one slot lets foundry crate supply its rare relic")
	game.progression.store.path = path + "/missing/profile.json"
	var saved_generation: int = model.generation
	check(game.combat.finish_run(false, "extracted"), "Combat extraction API accepts successful exit")
	check(game.expedition.snapshot().pending_result and game.expedition.active and game.expedition.backpack.get("relic", 0) == 1, "Failed result write keeps extracted cargo pending in memory")
	check(_button(game.hud.run_menu, "action_id", "retry_save") != null and _button(game.hud.run_menu, "action_id", "restart") == null, "Failed-save result offers retry instead of losing cargo on restart")
	game.show_start_menu()
	game.restart_run()
	check(game.screen_state == "result" and model.generation == saved_generation and game.expedition.snapshot().pending_result, "Menu and restart cannot discard an unsaved extraction")
	check(not auto_accept_quit, "Application handles window close explicitly before quitting")
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await process_frame
	check(is_instance_valid(game) and game.screen_state == "result" and game.expedition.snapshot().pending_result and game.expedition.backpack.get("relic", 0) == 1, "Window close with failed persistence keeps SceneTree alive and extracted cargo pending")
	game.progression.store.path = path
	_press(game.hud.run_menu, "action_id", "retry_save")
	var committed_xp: int = game.expedition.snapshot().total_xp
	game.hud.menu_action_requested.emit("retry_save", "")
	check(not game.expedition.snapshot().pending_result and game.expedition.snapshot().total_xp == committed_xp and game.expedition.snapshot().stash.get("relic", 0) == 1, "Successful retry banks the pending cargo and XP exactly once")
	check(game.screen_state == "result" and not game.expedition.active and game.expedition.backpack.is_empty(), "Extraction displays result and closes raid inventory")
	loaded = Store.new(path).load_profile()
	check(loaded.expedition.stash.get("scrap", 0) == 6 and loaded.expedition.stash.get("weapon_parts", 0) == 2 and loaded.expedition.stash.get("relic", 0) == 1, "A newly loaded profile contains all extracted cargo")
	check(loaded.expedition.xp > 0 and loaded.expedition.quests.first_delivery.progress == 6, "Account experience and delivery progress survive disk reload")
	_press(game.hud.run_menu, "action_id", "menu")
	_press(game.hud.run_menu, "action_id", "hideout")
	_tab(panel, "quests")
	var credits_before: int = game.expedition.snapshot().credits
	_press(panel, "expedition_action", "claim:first_delivery")
	check(game.expedition.snapshot().credits == credits_before + 180 and game.progression.profile.expedition.quests.first_delivery.status == "claimed" and game.expedition.snapshot().stash.get("scrap", 0) == 0, "Claim button transfers delivered scrap and pays the account task reward")
	_tab(panel, "trade")
	credits_before = game.expedition.snapshot().credits
	_press(panel, "expedition_action", "sell:relic")
	check(game.expedition.snapshot().credits == credits_before + 125 and not game.expedition.snapshot().stash.has("relic"), "Trader sells extracted relic for account credits")
	_tab(panel, "stash")
	_press(panel, "expedition_action", "equip:fuel_cell")
	_key(game, KEY_ESCAPE)
	var saved_stash: Dictionary = Store.new(path).load_profile().expedition.stash.duplicate(true)
	await _start(game, "start")
	check(game.expedition.backpack.get("fuel_cell", 0) == 1, "Second raid carries the fuel cell packed through the real hideout")
	model.spawn_pickup(model.player.position, 1)
	model._update_pickups(0.0)
	game.combat._publish()
	check(game.expedition.backpack.get("scrap", 0) == 1, "Second raid can collect fresh cargo")
	model.damage_player(99999)
	game.combat._sync_model_to_vehicle()
	game.combat._publish()
	for index in 52:
		game.session_flow.advance(0.05)
	check(game.screen_state == "result" and not game.expedition.active and not game.expedition.last_result.success, "Actual lethal damage and death cinematic settle failed raid")
	loaded = Store.new(path).load_profile()
	check(loaded.expedition.stash == saved_stash and game.expedition.last_result.lost.get("scrap", 0) == 1 and game.expedition.last_result.lost.get("fuel_cell", 0) == 1 and loaded.expedition.loadout.is_empty(), "Failed raid loses carried loot while extracted vault remains unchanged on disk")
	game.queue_free()
	await process_frame
	paused = false
	print("EXPEDITION_FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
