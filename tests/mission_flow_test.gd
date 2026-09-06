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

func _run() -> void:
	var game = Main.instantiate()
	var path := "/private/tmp/iron-mission-flow-%d.json" % Time.get_ticks_usec()
	game.profile_path = path
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	check(game.expedition.snapshot().quests.size() == 126, "Actual Main loads all 126 contracts")
	check(game.expedition.action("accept", "road_keeper"), "Accept persistent hunting contract before raid")
	check(game.expedition.action("accept", "first_delivery"), "Accept persistent delivery contract before raid")
	game._menu_action("start", "")
	await game.run_prepared
	for index in 60:
		game.session_flow.advance(0.05)
	var model = game.combat.model
	check(game.screen_state == "running", "Actual Main raid starts")
	model.player.speed = 12.0
	var before: float = game.expedition.missions.metrics.get("distance", 0.0)
	for index in 20:
		game.session_flow.advance(0.05)
		game._physics_process(0.05)
	check(float(game.expedition.missions.metrics.get("distance", 0)) > before + 8.0, "Main samples driving distance using live simulation time")
	check(game._mission_hint.visible and "0/12" in game._mission_hint.text, "Live HUD shows accepted hunting objective")
	game._toggle_pause()
	before = game.expedition.missions.metrics.seconds
	for index in 20:
		game.session_flow.advance(0.05)
		game._physics_process(0.05)
	check(game.expedition.missions.metrics.seconds == before, "Paused menu does not advance survival or time objectives")
	game._resume()
	game.session_flow.clock.request_hit_stop(1.0)
	game.session_flow.advance(0.01)
	game._physics_process(0.01)
	check(game.expedition.missions.metrics.seconds == before, "Hit stop does not advance mission simulation time")
	for index in 12:
		var enemy: Dictionary = model.spawn_enemy("rifleman", Vector3(700 + index, 0, 700), {"counts_toward_wave": false})
		model.kill_enemy(enemy)
	game.combat._publish()
	check(game.expedition.missions.metrics.get("kills", 0) == 12, "Actual combat deaths reach mission tracker once each")
	game.combat._publish()
	check(game.expedition.missions.metrics.kills == 12, "Publishing consumed combat events cannot duplicate kills")
	model.player.pending_upgrades = 0
	game._update_mission_hint()
	check("12/12" in game._mission_hint.text, "Live HUD reflects completed unbanked combat objective")
	check(game.progression.profile.expedition.quests.road_keeper.progress == 0, "Combat progress is unbanked during raid")
	var convoy: Dictionary = game.world.activities.announce("raiderSupplyConvoy", {"position": Vector3(400, 0, 0)})
	game.world.activities.finish(convoy, "completed")
	game.combat._publish()
	check(game.expedition.missions.metrics.get("convoys", 0) == 1, "Real completed convoy reaches mission event adapter")
	model.damage_player(10)
	game.combat._publish()
	check(game.expedition.missions.metrics.get("damage_taken", 0) == 10, "Real damage reaches no-damage mission condition")
	for index in 7:
		model.spawn_pickup(model.player.position, 1)
	model._update_pickups(0.0)
	game.combat._publish()
	check(game.expedition.backpack.get("scrap", 0) == 6, "Actual pickups provide mission delivery cargo")
	check(game.combat.finish_run(false, "extracted"), "Successful combat exit settles missions")
	var saved: Dictionary = Store.new(path).load_profile()
	check(saved.expedition.quests.road_keeper.progress == 12 and saved.expedition.quests.first_delivery.progress == 6, "Combat and loot objective progress both survive profile reload")
	var credits: int = game.expedition.snapshot().credits
	check(game.expedition.action("claim", "road_keeper"), "Banked hunting mission reward is claimable")
	check(not game.expedition.action("claim", "road_keeper") and game.expedition.snapshot().credits == credits + 260, "Claim is paid exactly once")
	check(game.expedition.action("claim", "first_delivery") and not game.expedition.snapshot().stash.has("scrap"), "Delivery claim consumes extracted cargo from actual stash")
	game._update_mission_hint()
	check(not game._mission_hint.visible, "Completed and claimed contracts leave live HUD")
	game.queue_free()
	await process_frame
	paused = false
	print("Mission flow: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
