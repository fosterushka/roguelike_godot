extends SceneTree
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	Locale.settings_path = "/private/tmp/iron-feedback-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	var model := preload("res://modules/combat/combat_model.gd").new()
	var progression := preload("res://modules/progression/progression.gd").new("/private/tmp/iron-mount-test-%d.json" % Time.get_ticks_usec())
	progression.setup(model)
	model.player.coins = 1000
	model.player.level = 2
	check(progression.buy_upgrade("trailer"), "Trailer purchase")
	var coins: int = model.player.coins
	for id in ["module:bazooka:missing:0", "module:bazooka:trailer-1:3", "module:bazooka:trailer-1:-1", "module:bazooka:trailer-1:no", "module:bazooka:crawler:0", "module:bazooka:trailer-1:0:extra"]:
		check(not progression.buy_upgrade(id) and model.player.coins == coins and model.weapons.size() == 1, "Invalid mount cannot charge coins or create equipment: " + id)
	check(progression.buy_upgrade("module:bazooka:trailer-1:1") and model.weapons[-1].mount == {"carrierId": "trailer-1", "slot": 1}, "Weapon installs on requested trailer slot")
	coins = model.player.coins
	check(not progression.buy_upgrade("module:radar:trailer-1:1") and model.player.coins == coins and model.player.radar_range == 0, "Occupied mount refuses passive without charge")
	check(progression.buy_upgrade("module:radar:crawler:2") and model.player.radar_range == 40, "Radar upgrade installs in requested free slot")
	var radar := preload("res://presentation/ui/radar.gd").new()
	root.add_child(radar)
	var camera := Camera3D.new()
	root.add_child(camera)
	var data := {"player": {"hp": 100, "position": Vector3.ZERO, "radar_range": 0.0}, "enemies": [{"id": 1, "position": Vector3(50,0,0)}, {"id": 2, "position": Vector3(400,0,0)}, {"id": 3, "position": Vector3(20,0,0), "dead": true}, {"id": 4, "position": Vector3(10,0,0), "allegiance": "friendly"}]}
	radar.update_state(data, camera)
	check(radar.visible and radar.detected_hostiles().is_empty(), "Basic map visible but has no enemy intelligence")
	data.player.radar_range = 260.0
	radar.update_state(data, camera)
	check(radar.detected_hostiles().size() == 1 and radar.detected_hostiles()[0].id == 1, "Upgrade detects live hostile within range only")
	var markers := preload("res://presentation/ui/world_markers.gd").new()
	root.add_child(markers)
	camera.position = Vector3(0,20,20)
	camera.look_at(Vector3.ZERO)
	markers.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	markers.size = Vector2(960,600)
	data.enemies[0].position = Vector3(100,0,0)
	data.player.radar_range = 0
	markers.update_state(data,camera)
	markers.update_world({"support": {"airdrops": [{"id": 1,"position": Vector3(500,0,0)}]}})
	check(markers.edge_candidates().size() == 1 and markers.edge_candidates()[0].id == "airdrops:1", "Base edge hints show supplies, hide enemies")
	data.player.radar_range = 260
	markers.update_state(data,camera)
	check(markers.edge_candidates().size() == 2, "Radar unlocks nearby offscreen enemy hint")
	data.player.radar_range = 0
	markers.update_state(data,camera)
	check(markers.edge_candidates().size() == 1, "Removing radar hides enemy hints again")
	var slot := preload("res://presentation/ui/ability_slot.gd").new()
	root.add_child(slot)
	slot.update_state({"nitro_cooldown": 1},true)
	check(slot.disabled and slot._normal.border_width_left == 3 and slot._normal.bg_color == Color("67471d") and slot._hover.border_width_left == 3, "Selected cooling slot keeps strong outline and background under hover")
	slot.update_state({},false)
	check(slot._normal.border_width_left == 1 and slot._normal.bg_color == Color("18201b"), "Previous slot restores neutral styling")
	var game := preload("res://app/main.tscn").instantiate()
	game.profile_path = "/private/tmp/iron-feedback-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	game._set_screen("running")
	game.vehicle.fuel = game.vehicle.max_fuel - 2
	var previous_coins: int = game.combat.model.player.coins
	var previous_xp: int = game.combat.model.player.xp
	var drop: Dictionary = game.world.support.spawn_airdrop(game.vehicle.global_position)
	drop.landed = true
	game.world.support._update_airdrops(0)
	var rewards := 0
	for event: Dictionary in game.world.support.drain_events():
		if event.kind == "airdrop_claimed":
			rewards += 1
			check(event.salvage == game.combat.model.player.coins - previous_coins and event.xp == game.combat.model.player.xp - previous_xp and event.fuel == 2, "Airdrop reports actual credited rewards including fuel cap")
			check(not event.blueprint.is_empty() and game.combat.model.player.unlocked_weapons.has(event.blueprint), "Reported blueprint is actually unlocked")
			game._on_world_event(event)
	check(rewards == 1 and game.hud.reward_notice.visible and game.hud.reward_notice.label.text.contains("SUPPLIES COLLECTED") and game.hud.reward_notice.label.text.contains("Fuel +2") and game.hud.reward_notice.label.text.contains("Install in Armory"), "Claim flows through application to readable reward receipt")
	game.world.support._update_airdrops(0)
	check(game.world.support.drain_events().is_empty(), "Collected airdrop cannot grant or notify twice")
	for type: String in game.combat.model._catalog:
		if game.combat.model._catalog[type].has("projectile") and not game.combat.model.player.unlocked_weapons.has(type):
			game.combat.model.player.unlocked_weapons.append(type)
	drop = game.world.support.spawn_airdrop(game.vehicle.global_position)
	drop.landed = true
	game.world.support._update_airdrops(0)
	for event: Dictionary in game.world.support.drain_events():
		if event.kind == "airdrop_claimed":
			game._on_world_event(event)
			check(event.blueprint.is_empty() and event.fuel == 0 and not game.hud.reward_notice.label.text.contains("Blueprint:"), "Full fuel and all blueprints give honest zero fuel, no phantom unlock")
	game.hud.show_world_banner("WAVE 2", "Next wave")
	check(game.hud.reward_notice.label.text.contains("SUPPLIES COLLECTED"), "Wave banner cannot overwrite loot receipt")
	game._toggle_pause()
	var remaining: float = game.hud.reward_notice.remaining
	game.hud.reward_notice._process(20)
	check(game.hud.reward_notice.remaining == remaining, "Paused receipt timer is preserved")
	game._set_language("ru")
	check(game.hud.reward_notice.label.text.contains("ПРИПАСЫ ПОЛУЧЕНЫ") and game.hud.reward_notice.label.text.contains("Топливо +0"), "Existing receipt changes to Russian")
	game.hud.set_loading(true)
	check(game.hud.reward_notice.reward.is_empty() and not game.hud.reward_notice.visible, "Restart clears old receipt")
	game.queue_free()
	radar.queue_free()
	markers.queue_free()
	camera.queue_free()
	slot.queue_free()
	paused = false
	await process_frame
	DirAccess.remove_absolute(Locale.settings_path)
	print("Feedback tests: %d/%d passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
