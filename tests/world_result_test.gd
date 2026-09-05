extends SceneTree
const Main = preload("res://app/main.tscn")
const Rules = preload("res://modules/world/activities/activity_rules.gd")
var checks := 0
var failures := 0
var results: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron_caravan_world_result_%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	game.combat.combat_event.connect(func(event: Dictionary) -> void:
		if event.kind == "result": results.append(event)
	)
	game.hud.menu_action_requested.emit("start", "")
	await game.run_ready
	game.vehicle.global_position = Vector3(1250, 0, 0)
	game.world._update_boundary(15.0)
	check(results.is_empty() and game.screen_state == "death", "Boundary starts local death cinematic before final result")
	for index in 50:
		game.session_flow.advance(0.05)
	check(results.size() == 1 and results[0].reason == "boundary", "Boundary publishes result after source death timer")
	check(game.screen_state == "result" and paused and not game.vehicle._driving_enabled, "Boundary result reaches real screen and freezes input")
	check(game.vehicle.health == 0 and game.vehicle.global_position.x == 1250, "Boundary death keeps final position")
	check(game.progression.contracts.ended and not game.progression.contracts.active and game.progression.contracts.seen.has("result:end"), "Boundary closes actual profile run")
	game.world._update_boundary(15.0)
	game.combat._physics_process(1.0)
	check(results.size() == 1, "Repeated boundary update cannot finish twice")
	check(game.progression.flush(), "Boundary result profile persists")
	game.hud.menu_action_requested.emit("restart", "")
	await game.run_ready
	check(game.progression.contracts.active and not game.progression.contracts.ended and game.screen_state == "running", "Restart opens fresh run after boundary result")
	var site: Dictionary = {}
	for candidate: Dictionary in game.arena.world_layout.villages:
		game.vehicle.global_position = Rules.point(candidate)
		var possible: Dictionary = game.world.activities._nearest_site()
		if not possible.is_empty() and not possible.anchor.is_empty():
			site = possible
			break
	check(not site.is_empty(), "Real source world provides extraction site")
	game.world.activities.credits = 2
	game.vehicle.motion.speed = 0
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	game._input(interact)
	check(game.world.activities.extraction.active, "Actual world interaction activates extraction")
	game.vehicle.global_position = game.world.activities.extraction.position
	var final_position: Vector3 = game.vehicle.global_position
	game.world.activities._update_extraction(30.0)
	check(results.size() == 2 and results[1].extracted and not results[1].won, "Extraction publishes one nonvictory result immediately")
	check(game.screen_state == "result" and paused and not game.vehicle._driving_enabled, "Extraction reaches real result screen")
	check(game.vehicle.health > 0 and game.vehicle.global_position == final_position, "Extraction retains living player and final position")
	check(game.progression.contracts.ended and not game.progression.contracts.active and game.progression.profile.lifetimeStats.victories == 0, "Extraction closes profile without granting victory")
	game.combat.set_running(true)
	game.world.activities._update_extraction(30.0)
	check(not game.combat.model.running and results.size() == 2, "Extraction terminal state cannot resume or repeat result")
	check(game.progression.flush(), "Extraction profile persists")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.profile_path))
	check(saved.lifetimeStats.runs == 2 and saved.lifetimeStats.victories == 0, "Saved profile records exactly two starts and zero victories")
	game.queue_free()
	await process_frame
	paused = false
	print("World results: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
