extends SceneTree

const MainScene = preload("res://app/main.tscn")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = MainScene.instantiate()
	game.profile_path = "/private/tmp/iron_caravan_session_test_%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	_check(paused and not game.ready_to_drive, "Boot freezes simulation until resources are prepared")
	await game.game_ready
	_check(paused and game.ready_to_drive and game.screen_state == "menu", "Prepared game waits at the start menu")
	_check(game.combat.model.elapsed == 0 and game.vehicle.fuel == game.vehicle.max_fuel, "Loading and menu consume neither simulation time nor fuel")
	_check(game.camera.current and game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Orthographic camera is active")
	game.hud.menu_action_requested.emit("start", "")
	await game.run_ready
	_check(not paused and game.screen_state == "running", "Start menu launches local run")
	Input.action_press("drive_forward")
	await _frames(120)
	_check(game.vehicle.position.z > 2.0, "Assembled vehicle moves along source road")
	_check(game.vehicle.velocity.length() > 0.1, "Camera receives actual vehicle velocity")
	var before: Vector3 = game.vehicle.position
	var fuel_before: float = game.vehicle.fuel
	var elapsed_before: float = game.combat.model.elapsed
	_key(KEY_P)
	_check(paused and game.hud._pause_overlay.visible, "P opens pause through actual input")
	await _frames(12)
	_check(game.vehicle.position == before and game.vehicle.fuel == fuel_before and game.combat.model.elapsed == elapsed_before, "Pause freezes vehicle, fuel and combat")
	Input.action_release("drive_forward")
	_key(KEY_ESCAPE)
	_check(not paused, "Esc resumes even when pause button has focus")
	_key(KEY_B)
	_check(paused and game.screen_state == "armory", "Armory has a separate paused state")
	_key(KEY_SPACE)
	_check(game.combat.model.player.nitro_timer == 0.0 and game.screen_state == "armory", "Armory consumes gameplay Space without triggering its focused close button")
	_key(KEY_ESCAPE)
	_key(KEY_1)
	_key(KEY_SPACE)
	_check(game.combat.model.player.nitro_timer > 0.0, "Hotbar activates source nitro slot zero")
	_check(game.vehicle.player_stats.nitro_timer > 0.0, "Nitro stat reaches vehicle movement tuning")
	game.vehicle.health = 5.0
	_key(KEY_P)
	_key(KEY_R)
	_check(game.screen_state == "pause" and game.vehicle.health == 5.0, "R leaves paused run unchanged")
	game.hud.restart_requested.emit()
	await game.run_ready
	_check(not paused and game.vehicle.position == Vector3.ZERO and game.vehicle.motion.speed == 0.0, "Pause restart button resets motion")
	_check(game.vehicle.health == game.vehicle.max_health and game.vehicle.fuel == game.vehicle.max_fuel, "Restart restores health and fuel")
	_check(game.combat.model.player.nitro_timer == 0.0 and game.combat.model.elapsed == 0.0, "Restart clears simulation and ability timers")
	_check(game.arena.ARENA_HALF_SIZE == 1248.0, "World preserves original 1248 radius")
	game.queue_free()
	await process_frame
	paused = false
	print("Offline session: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func _frames(count: int) -> void:
	for _frame in count:
		await physics_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
