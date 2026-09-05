extends SceneTree
# Controlled integration scenario. Enemy damage is injected; this is not a balance playthrough.
const Main = preload("res://app/main.tscn")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
var checks := 0
var failures := 0
var events: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var game = Main.instantiate()
	var profile_file := "/private/tmp/iron-full-run-%d.json" % Time.get_ticks_usec()
	game.profile_path = profile_file
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	check(is_instance_valid(game.vehicle) and game.arena.source_world.get_child_count() > 20, "Assembled boot contains actual rendered geometry and vehicle")
	game.hud.menu_action_requested.emit("contract", "combined-arms")
	check(game.progression.profile.selectedContractIds.is_empty(), "Removed contract menu route cannot select a contract")
	game.hud.menu_action_requested.emit("start", "")
	await game.run_ready
	game.combat.combat_event.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	game.session_flow.set_physics_process(false)
	game.set_physics_process(false)
	game.combat.set_physics_process(false)
	game.world.set_physics_process(false)
	game.vehicle.set_physics_process(false)
	var model = game.combat.model
	model.player.coins = 200
	game._toggle_armory()
	game.hud.menu_action_requested.emit("buy", "module:bazooka")
	check(model.weapons.any(func(weapon: Dictionary) -> bool: return weapon.type == "bazooka"), "Actual armory equips a second weapon")
	game._resume()
	var waves: Dictionary = {}
	var ticks := 0
	while model.status not in ["complete", "dead", "extracted"] and ticks < 8000:
		game.session_flow.advance(0.05)
		waves[model.wave] = true
		for enemy: Dictionary in model.enemies.duplicate():
			if enemy.dead:
				continue
			if enemy.get("boss", false):
				for component: Dictionary in enemy.components:
					if component.targetable:
						model.damage_enemy(component.id, 99999)
			else:
				model.damage_enemy(enemy.id, 99999)
		game.combat._physics_process(0.1)
		game._physics_process(0.1)
		while game.screen_state == "choice":
			var rows: Array = game.progression.get_shop_state().choices
			if rows.is_empty():
				check(false, "Level-up has a selectable source choice")
				break
			game.hud.menu_action_requested.emit("choose", rows[0].id)
		ticks += 1
	check(model.status == "complete" and waves.keys() == [1, 2, 3, 4, 5, 6], "Real spawn queues and intermissions complete all six waves")
	for kind: String in ["jammerTruck", "repairCrawler", "minelayer"]:
		check(events.any(func(event: Dictionary) -> bool: return event.kind == "spawn" and event.get("enemy_kind", "") == kind), "Real composed run spawns newly enabled " + kind)
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == "boss_component_destroyed").size() == 5, "Leviathan victory requires destroying all five targetable components")
	check(game.screen_state == "result" and paused and not game.vehicle._driving_enabled, "Victory event displays real result screen and freezes drive")
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == "result").size() == 1, "Victory emits exactly one result")
	check(game.progression.profile.completedContractIds.is_empty() and game.progression.profile.lifetimeStats.victories == 1, "Winning without contracts records exactly one victory")
	check(not game.sound.last_events.has("contractComplete"), "Run without contracts has no contract completion notification")
	check(game.progression.flush(), "Victory profile flush succeeds")
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_file))
	check(stored.completedContractIds.is_empty() and stored.lifetimeStats.victories == 1, "Reloaded disk data contains one victory without contract rewards")
	var before: float = model.elapsed
	for index in 10:
		game.combat._physics_process(0.1)
	check(model.elapsed == before and events.filter(func(event: Dictionary) -> bool: return event.kind == "result").size() == 1, "Finished run cannot advance or repeat rewards")
	var old_world: int = game.arena.source_world.get_instance_id()
	game.session_flow.set_physics_process(true)
	game.run_seed_override = 991827
	game.hud.menu_action_requested.emit("restart", "")
	await game.run_ready
	check(game.run_seed == 991827 and not is_instance_id_valid(old_world), "Result restart replaces world with another native seed")
	check(model.wave == 1 and model.player.kills == 0 and model.projectiles.is_empty() and model.pickups.is_empty(), "Restart removes previous combat transients and resets wave")
	check(game.progression.profile.lifetimeStats.victories == 1 and game.progression.profile.lifetimeStats.runs == 2, "Restart retains durable victory and begins exactly one new run")
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(FileAccess.file_exists(profile_file), "Exit lifecycle persists isolated profile")
	game.queue_free()
	await process_frame
	paused = false
	print("Controlled full run: %d checks, %d failures, %d simulation ticks" % [checks, failures, ticks])
	quit(0 if failures == 0 else 1)
