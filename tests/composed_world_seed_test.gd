extends SceneTree
const Main = preload("res://app/main.tscn")
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
	game.profile_path = "/private/tmp/iron-seed-session-%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await game.game_ready
	var child_count: int = game.world.get_child_count()
	var previous_world: int = game.arena.source_world.get_instance_id()
	var layouts: Array = []
	for seed_value in [0, 991827]:
		game.run_seed_override = seed_value
		game.restart_run()
		check(paused and game.screen_state == "loading" and not game.ready_to_drive, "New run freezes before generation and paint")
		var generation: int = game.combat.model.generation
		game.restart_run()
		check(game.combat.model.generation == generation, "Repeated restart during loading cannot queue another run")
		await game.run_ready
		check(game.run_seed == seed_value and int(game.arena.world_layout.seed) == seed_value, "Gameplay arena uses selected native seed")
		check(game.combat.model.random.seed == seed_value and game.world._seed == seed_value and game.world.weather.seed_value == seed_value, "Combat and weather share world seed")
		check(game.world.activities._villages.keys() == game.world.activities._village_props.keys(), "Activities bind only replacement villages")
		check(game.world.props.records.size() == game.arena.world_layout.props.size() + game.arena.world_layout.rockObstacles.size(), "All generated props and rock colliders bind together")
		check(game.world.get_child_count() == child_count and not is_instance_id_valid(previous_world), "Old world freed and runtime children remain bounded")
		check(game.world.ambient.critters.size() > 0 and game.world.ambient.animators.size() > 0, "Generated villagers/grazers and machinery are live descriptors")
		check(game.vehicle.position == Vector3.ZERO and game.world.is_spawn_clear(Vector3.ZERO, 2.7), "Source start road clears player spawn")
		check(game.combat.model.elapsed == 0 and game.world.weather.elapsed >= 2.65 and game.vehicle.fuel == game.vehicle.max_fuel, "Generation/warmup/countdown consume no gameplay or fuel; intro weather advances raw")
		check(game.hud.radar.layout.seed == seed_value, "Radar roads and villages use replacement world")
		layouts.append(game.arena.world_layout.roads)
		previous_world = game.arena.source_world.get_instance_id()
		game._toggle_pause()
		var point: Vector3 = game.world.ambient.critters[0].group.position
		await process_frame
		check(game.world.ambient.critters[0].group.position == point, "Pause freezes ambient figures")
		var prop: Dictionary = game.world.props.records[game.arena.world_layout.props[0].id]
		game.world.damage_props(prop.position, 0.1, 9999)
		check(prop.destroyed, "Actual generated prop responds to combat damage")
	check(layouts[0] != layouts[1], "Two composed seeds create different real roads")
	check(game.progression.profile.lifetimeStats.runs == 2 and game.progression.flush(), "Replacement retains and flushes isolated progression profile")
	game.run_seed_override = -1
	await game.restart_run()
	var random_seed: int = game.run_seed
	check(random_seed >= 0 and random_seed <= 0xffffffff, "Default local seed is unsigned32bit")
	await game.restart_run()
	check(game.run_seed != random_seed and game.progression.profile.lifetimeStats.runs == 4, "Each normal new run gets another random seed and retains profile")
	game.queue_free()
	await process_frame
	paused = false
	print("Composed world seeds: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
