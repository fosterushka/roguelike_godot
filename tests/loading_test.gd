extends SceneTree

const Main = preload("res://app/main.tscn")
const Preparation = preload("res://infrastructure/loading/game_preparation.gd")
var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-loading-profile-%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await game.game_ready
	_check(paused and game.screen_state == "menu", "Preparation does not start simulation")
	_check(game.preparation.completed == game.preparation.total, "Every manifest resource loaded")
	_check(game.preparation.errors.is_empty(), "Resource preparation succeeds")
	_check(game.preparation.procedural_models == ["ArmoredWheelVehicle", "SteeringWheelTrailer"], "Both procedural wheel rigs enter covered preparation")
	var stats: Dictionary = game.combat.model.player.duplicate(true)
	var camera_transform: Transform3D = game.camera.global_transform
	var size: float = game.camera.size
	var seed_value: int = game.run_seed
	var events: Array = []
	game.combat.combat_event.connect(func(event: Dictionary) -> void: events.append(event))
	game.world.world_event.connect(func(event: Dictionary) -> void: events.append(event))
	_check(await game.world_warmup.prepare(game, func(_label: String, _progress: float) -> void: pass), "Covered world preparation succeeds")
	_check(stats == game.combat.model.player, "Warmup preserves health fuel currency and player state")
	_check(events.is_empty() and game.run_seed == seed_value, "Warmup emits no gameplay events and preserves seed")
	_check(game.camera.global_transform == camera_transform and game.camera.size == size, "Warmup restores camera")
	_check(game.world_warmup.headless and game.world_warmup.rendered_views == 0, "Headless never reports GPU preparation")
	paused = false
	_check(not await game.world_warmup.prepare(game, Callable()), "World preparation refuses active simulation")
	paused = true
	var invalid := Preparation.new()
	# Missing manifest resources are a load failure, never a ready screen.
	var temp := "/private/tmp/iron-bad-manifest-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	file.store_string('{"resources":["res://missing-test-texture.png"],"data":[]}')
	file.close()
	invalid.manifest_path = temp
	_check(not await invalid.validate_and_load(game, func(_label: String, _progress: float) -> void: pass), "Missing resource fails preparation")
	_check(invalid.errors.size() == 1, "Original missing resource is reported")
	DirAccess.remove_absolute(temp)
	game.queue_free()
	await process_frame
	paused = false
	print("Loading: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
