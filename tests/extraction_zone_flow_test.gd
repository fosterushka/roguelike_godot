extends SceneTree

const Main = preload("res://app/main.tscn")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []
var wave_events: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _key(game, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	game._input(event)

func _start(game) -> void:
	game._menu_action("start" if game.screen_state == "menu" else "restart", "")
	await game.run_prepared
	for index in 60:
		game.session_flow.advance(0.05)
	check(game.screen_state == "running" and game.expedition.active, "Actual Main start enters active raid after countdown")

func _place(game, point: Vector3) -> void:
	game.vehicle.global_position = Vector3(point.x, Terrain.height_at(point.x, point.z) + 0.4, point.z)
	game.vehicle.motion.x = point.x
	game.vehicle.motion.z = point.z
	game.vehicle.motion.speed = 0.0
	game.vehicle.velocity = Vector3.ZERO
	game.combat._sync_vehicle_to_model()

func _tick(game, count: int) -> void:
	for index in count:
		game.session_flow.advance(0.05)
		game.world._physics_process(0.05)
		game.combat._physics_process(0.05)

func _defenders(game) -> Array:
	return game.combat.model.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.get("extraction_defender", false) and not enemy.dead)

func _loot(game) -> void:
	for index in 3:
		game.combat.model.spawn_pickup(game.combat.model.player.position, 1)
	game.combat.model._update_pickups(0.0)
	game.combat._publish()

func _run() -> void:
	var game = Main.instantiate()
	var path := "/private/tmp/iron-extraction-zones-%d.json" % Time.get_ticks_usec()
	game.profile_path = path
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.combat.combat_event.connect(func(event: Dictionary) -> void:
		if event.get("kind", "") == "result":
			results.append(event.duplicate(true)))
	game.world.world_event.connect(func(event: Dictionary) -> void:
		if event.get("kind", "") == "extraction_wave":
			wave_events.append(event.duplicate(true)))
	game.progression.profile.expedition.credits = 0
	check(game.expedition.action("accept", "first_exit"), "New extraction mission accepts before raid")
	check(game.expedition.action("accept", "exit_one_manifest"), "New site-specific cargo mission accepts before raid")
	await _start(game)
	var activities = game.world.activities
	var model = game.combat.model
	var initial: Dictionary = activities.get_extraction_state()
	var sites: Array = initial.get("sites", [])
	check(sites.size() == 3 and initial.get("visible", false) and not initial.get("active", true), "Three independent extraction sites are visible before any objective")
	if sites.is_empty():
		game.queue_free()
		await process_frame
		paused = false
		print("Extraction zone flow tests: ", checks - failures, "/", checks)
		quit(1)
		return
	check(float(initial.get("duration", 0.0)) == 20.0 and activities.credits == 0 and game.expedition.snapshot().credits == 0, "Extraction lasts twenty seconds and starts with both credit balances zero")
	for site: Dictionary in sites:
		var point: Vector3 = site.position
		var radius := float(site.radius)
		check(radius >= 12.0 and Vector2(point.x, point.z).length() < 900.0, "Site is a full vehicle-sized zone inside playable terrain: " + str(site.id))
		check(game.world.props.first_segment(point, point, radius, true).is_empty(), "Entire extraction zone clears solid props and rocks: " + str(site.id))
		var low := Terrain.height_at(point.x, point.z)
		var high := low
		for segment in 8:
			var sample: Vector3 = point + Vector3(cos(segment * TAU / 8.0), 0, sin(segment * TAU / 8.0)) * radius
			var height := Terrain.height_at(sample.x, sample.z)
			low = minf(low, height)
			high = maxf(high, height)
		check(high - low <= 4.1, "Extraction site has gently varying driveable ground: " + str(site.id))
	game.world._publish()
	check(game.hud.radar.world_state.get("extraction", {}).get("sites", []).size() == 3, "Real world publication delivers all sites to radar before discovery")
	check(game.hud.radar.extraction_sites().size() == 3, "Radar exposes every extraction site independently of exploration fog")
	var zone_view = game.world._activity_view._extraction_zones
	check(zone_view.sites.size() == 3, "World view creates persistent geometry for every site before requesting extraction")
	var all_visible := true
	var no_colliders := true
	for entry: Dictionary in zone_view.sites.values():
		all_visible = all_visible and entry.root.visible and not entry.label.text.is_empty()
		no_colliders = no_colliders and entry.root.find_children("*", "CollisionObject3D", true, false).is_empty()
	check(all_visible and no_colliders, "Extraction zones have visible labels and visual-only geometry that cannot block the vehicle")
	for village: Dictionary in activities._villages.values():
		village.intact = false
		village.consumed = true
	check(activities.get_extraction_state().sites == sites, "Destroyed villages do not remove or move independent extraction sites")
	var site: Dictionary = sites[0]
	_place(game, site.position + Vector3(float(site.radius) + 10.0, 0, 0))
	_key(game, KEY_E)
	check(not activities.extraction.active, "Actual E input outside zone cannot start extraction")
	_place(game, site.position)
	check(activities.get_extraction_state().can_request, "Entering site makes extraction available with zero credits")
	_key(game, KEY_E)
	check(activities.extraction.active and model.player.get("extraction_active", false), "Actual E inside site starts extraction and combat defense mode")
	_key(game, KEY_E)
	check(activities.extraction.progress == 0.0, "Repeated E does not restart or advance extraction")
	_tick(game, 4)
	var attackers := _defenders(game)
	check(not attackers.is_empty() and attackers.size() <= 10, "Extraction schedules a bounded first wave of actual enemies")
	var tracked: Dictionary = attackers[0] if not attackers.is_empty() else {}
	var previous_distance: float = tracked.position.distance_to(model.player.position) if not tracked.is_empty() else 0.0
	model.player.hp = 100000.0
	model.player.max_hp = 100000.0
	game.combat._sync_model_to_vehicle()
	_tick(game, 45)
	check(not tracked.is_empty() and tracked.position.distance_to(model.player.position) < previous_distance - 0.5, "Spawned attackers advance toward the real player under normal combat AI")
	var hostile: Dictionary = model.spawn_enemy("rifleman", site.position + Vector3(8, 0, 0), {"counts_toward_wave": false})
	var before_hostile: float = activities.extraction.progress
	_tick(game, 1)
	check(not hostile.is_empty() and activities.get_extraction_state().hostile_count > 0 and activities.extraction.progress > before_hostile, "Defense countdown advances even with a live hostile inside extraction zone")
	var old_queue: Array[String] = model.spawn_queue.duplicate()
	var previous_flags := {}
	for enemy: Dictionary in model.enemies:
		previous_flags[enemy.id] = enemy.get("counts_toward_wave", true)
		enemy.counts_toward_wave = false
	model.spawn_queue.clear()
	model.wave = model.Waves.FINAL_WAVE
	model._wave_age = 2.0
	game.combat._physics_process(0.05)
	check(model.status == "combat" and game.screen_state == "running" and results.is_empty(), "Exhausted final ordinary wave cannot end a defending extraction early")
	model.wave = 1
	model.spawn_queue = old_queue
	for enemy: Dictionary in model.enemies:
		enemy.counts_toward_wave = previous_flags.get(enemy.id, false)
	var progress_before: float = activities.extraction.progress
	game._toggle_pause()
	_tick(game, 40)
	check(activities.extraction.progress == progress_before and game.screen_state == "pause", "Actual pause freezes extraction and enemy simulation")
	game._resume()
	_place(game, site.position + Vector3(float(site.radius) + 8.0, 0, 0))
	_tick(game, 30)
	check(activities.extraction.active and is_equal_approx(activities.extraction.progress, progress_before) and activities.get_extraction_state().mode == "leaving", "Leaving pauses countdown during cancellation grace")
	_tick(game, 45)
	check(not activities.extraction.active and not model.player.get("extraction_active", true), "Three seconds outside cancels defense and restores ordinary combat")
	_place(game, site.position)
	_key(game, KEY_E)
	check(activities.extraction.active and activities.extraction.progress == 0.0, "Returning and pressing E starts a clean new twenty-second defense")
	_loot(game)
	var carried: Dictionary = game.expedition.backpack.duplicate(true)
	check(not carried.is_empty(), "Physical combat pickups populate actual raid cargo before extraction")
	var advanced := 0
	var wave_count_before := wave_events.size()
	var peak_attackers := 0
	var final_cargo := carried.duplicate(true)
	while game.screen_state == "running" and advanced < 440:
		final_cargo = game.expedition.backpack.duplicate(true)
		_tick(game, 1)
		peak_attackers = maxi(peak_attackers, _defenders(game).size())
		advanced += 1
	check(advanced >= 390 and advanced <= 440 and game.screen_state == "result", "Surviving full defense timer reaches actual Main result screen")
	check(wave_events.size() >= wave_count_before + 2 and peak_attackers <= 10, "Timer schedules reinforcements while keeping live extraction attackers bounded across retries")
	check(results.size() == 1 and results[0].get("extracted", false) and model.status == "extracted", "Zone completion emits exactly one extracted result")
	var saved: Dictionary = Store.new(path).load_profile()
	check(saved.expedition.stash.get("scrap", 0) == final_cargo.get("scrap", 0) and saved.expedition.xp > 0, "Actual zone extraction saves carried loot and account XP to disk")
	check(saved.expedition.quests.first_exit.progress == 1 and saved.expedition.quests.exit_one_manifest.progress == 3, "Real E1 defense banks both new extraction and combined cargo mission objectives")
	check(game.expedition.action("claim", "first_exit") and game.expedition.action("claim", "exit_one_manifest"), "New defense mission rewards are claimable after actual zone extraction")
	saved = Store.new(path).load_profile()
	var earned_xp: int = saved.expedition.xp
	check(not game.combat.finish_run(false, "extracted") and Store.new(path).load_profile().expedition.xp == earned_xp, "Repeated completion cannot duplicate saved extraction rewards")
	await _start(game)
	activities = game.world.activities
	model = game.combat.model
	site = activities.get_extraction_state().sites[0]
	_place(game, site.position)
	_key(game, KEY_E)
	_loot(game)
	var stash_before_death: Dictionary = game.expedition.snapshot().stash
	model.damage_player(99999)
	game.combat._sync_model_to_vehicle()
	game.combat._publish()
	check(game.screen_state == "death" and not activities.extraction.active, "Lethal damage during extraction cancels defense and enters death cinematic")
	for index in 55:
		game.session_flow.advance(0.05)
	check(game.screen_state == "result" and not game.expedition.active and game.expedition.backpack.is_empty(), "Death result closes raid and removes carried cargo")
	check(Store.new(path).load_profile().expedition.stash == stash_before_death and not results[-1].get("extracted", false), "Failed extraction never deposits cargo or grants a successful result")
	await _start(game)
	activities = game.world.activities
	check(not activities.extraction.active and activities.extraction.progress == 0.0 and game.expedition.backpack.is_empty() and _defenders(game).is_empty(), "Restart after death has fresh timer, empty cargo, and no old attackers")
	site = activities.get_extraction_state().sites[0]
	_place(game, site.position)
	_key(game, KEY_E)
	check(activities.extraction.active, "Fresh raid can request extraction again without prior quests or credits")
	game.queue_free()
	await process_frame
	paused = false
	print("Extraction zone flow tests: ", checks - failures, "/", checks)
	quit(1 if failures else 0)
