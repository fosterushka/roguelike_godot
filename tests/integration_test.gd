extends SceneTree

const Main = preload("res://app/main.tscn")
var checks := 0
var failures := 0
var events: Array = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron_caravan_integration_%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	game.combat.combat_event.connect(func(event: Dictionary) -> void: events.append(event))
	game.hud.menu_action_requested.emit("start", "")
	await game.run_ready
	_check(game.vehicle.player_stats.weight == 12.0, "Source initial weight reaches drive controller")
	var model = game.combat.model
	var pickup: int = model.spawn_pickup(Vector3.ZERO, 100)
	game.session_flow.advance(1.0 / 60.0)
	game.combat._physics_process(1.0 / 60.0)
	_check(model.player.coins >= 135 and events.any(func(event: Dictionary) -> bool: return event.kind == "pickup"), "Real pickup simulation emits reward and credits economy")
	var coins: int = model.player.coins
	_check(not model.collect_pickup(pickup) and model.player.coins == coins, "Collected reward cannot credit twice")
	game._toggle_armory()
	game.hud.menu_action_requested.emit("buy", "module:bazooka")
	_check(model.weapons.any(func(weapon: Dictionary) -> bool: return weapon.type == "bazooka") and model.player.coins < coins, "Armory UI spends salvage and equips actual combat weapon")
	_check(game.vehicle.player_stats.weight > 12.0, "New weapon weight reaches movement tuning")
	_check(game.vehicle.get_node("VehicleView")._modules.size() == model.player.modules.size(), "Purchased combat weapon has a mounted original visual")
	var before_level: int = model.player.level
	game._resume()
	model.player.xp = model.player.xp_next
	game._physics_process(0.01)
	_check(paused and game.screen_state == "choice" and model.player.level == before_level + 1, "Earned XP pauses next simulation for level choice")
	var choices: Array = game.progression.get_shop_state().choices
	game.hud.menu_action_requested.emit("choose", choices[0].id)
	_check(game.screen_state == "choice", "Core choice leads to second source draft choice")
	choices = game.progression.get_shop_state().choices
	game.hud.menu_action_requested.emit("choose", choices[0].id)
	_check(not paused and model.player.pending_upgrades == 0, "Draft choice consumes pending upgrade and resumes")
	var enemy: Dictionary = model.spawn_enemy("rifleman", Vector3(0, 0, 8))
	game.combat.focus_next()
	_check(model.focus_id == enemy.id, "Focus API selects living enemy")
	model.damage_enemy(enemy.id, 99999)
	game.combat._publish()
	_check(events.any(func(event: Dictionary) -> bool: return event.kind == "death") and model.player.kills > 0, "Combat death reaches presentation and progression event route")
	model.damage_player(99999)
	game.combat._sync_model_to_vehicle()
	game.combat._publish()
	_check(paused and game.screen_state == "death" and not game.vehicle._driving_enabled, "Lethal damage starts source cinematic and freezes input")
	for index in 50:
		game.session_flow.advance(0.05)
	_check(game.screen_state == "result", "Result appears after2.4 raw cinematic seconds")
	var generation: int = model.generation
	game.hud.menu_action_requested.emit("restart", "")
	await game.run_ready
	_check(model.generation > generation and model.player.kills == 0 and model.player.weight == 12.0, "Result restart resets combat and progression together")
	_check(game.vehicle.get_node("VehicleView")._modules.size() == 1 and game.vehicle.get_node("VehicleView")._evolution_tier == 1, "Restart removes purchased module and evolution visuals")
	_check(game.progression.profile.lifetimeStats.runs >= 2, "Restart begins a fresh local profile run")
	_check(game.progression.flush(), "Profile writes successfully to isolated test path")
	game.queue_free()
	await process_frame
	paused = false
	print("Integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
