extends SceneTree
const Main = preload("res://app/main.tscn")
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
	game.profile_path = "/private/tmp/iron-session-flow-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	game.session_flow.set_physics_process(false)
	game.combat.combat_event.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	game.restart_run()
	await game.run_prepared
	check(game.screen_state == "countdown" and game.session_flow.clock.intro_remaining == 2.65, "Prepared world begins exact source countdown")
	check(game.world.foundries.foundries.size() == 10, "Initial foundries exist before countdown simulation")
	var prepared_generation: int = game.combat.model.generation
	for index in 5:
		game.session_flow.advance(0.05)
	game.restart_run()
	check(game.session_flow.clock.phase == "idle", "Restart cancels in-progress countdown before rebuild")
	await game.run_prepared
	check(game.combat.model.generation > prepared_generation and game.session_flow.clock.intro_remaining == 2.65, "Replacement countdown restarts full source duration in new generation")
	var enemy_count: int = game.combat.model.enemies.size()
	var fuel: float = game.vehicle.fuel
	Input.action_press("drive_forward")
	for action in ["pause_game", "armory", "activate_ability", "restart_run"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		game._input(event)
	check(game.screen_state == "countdown", "Countdown blocks pause/build/ability/restart keyboard shortcuts")
	var steps: Array = []
	for index in 80:
		game.session_flow.advance(0.05)
		if not steps.has(game.session_flow.clock.intro_step):
			steps.append(game.session_flow.clock.intro_step)
		game.vehicle._physics_process(0.05)
		game.combat._physics_process(0.05)
		game.world._physics_process(0.05)
		game._physics_process(0.05)
		if game.screen_state == "running":
			break
	check(steps == [3, 2, 1, 0], "HUD countdown follows 3/2/1/GO source sequence")
	check(game.combat.model.elapsed == 0 and game.combat.model.enemies.size() == enemy_count and game.vehicle.position == Vector3.ZERO and game.vehicle.fuel == fuel, "Countdown freezes enemies, weapons, driving and fuel")
	check(game.world.weather.elapsed >= 2.65 and game.session_flow.clock.resume_ease == 0, "Weather advances raw through intro while source resume starts at zero")
	game.session_flow.advance(0.05)
	check(game.session_flow.clock.simulation_delta > 0 and game.session_flow.clock.simulation_delta < 0.005, "First playable tick has source smooth resume")
	game.vehicle._physics_process(0.05)
	check(game.vehicle.motion.speed > 0, "Driving starts only after countdown")
	Input.action_release("drive_forward")
	var visual = game.vehicle.get_node("VehicleView")
	visual.set_process(false)
	check(visual.time_delta.is_valid(), "Live vehicle animation uses the shared run clock")
	var previous_speed: float = visual._player.speed
	visual._player.speed = 6.0
	var previous_wheel: float = visual._body.wheel_angle
	visual._process(0.025)
	visual._process(0.025)
	check(absf(visual._body.wheel_angle - previous_wheel - 6.0 * 0.9 * game.session_flow.clock.simulation_delta) < 0.000001, "Two render frames preserve one simulation interval during smooth resume")
	game.session_flow.clock.request_hit_stop(0.5)
	game.session_flow.advance(1.0 / 60.0)
	var frozen_visual: Dictionary = visual._body.duplicate(true)
	visual._process(0.05)
	check(visual._body == frozen_visual, "Hitstop freezes wheel, body and recoil animation clocks")
	game.session_flow.clock.hit_stop = 0.0
	visual._player.speed = previous_speed
	game._toggle_pause()
	game.session_flow.advance(0.05)
	check(game.session_flow.clock.simulation_delta == 0 and game.session_flow.clock.weather_delta == 0, "Manual pause freezes gameplay and weather")
	visual._process(0.05)
	check(visual._body == frozen_visual, "Pause also freezes explicitly advanced live visuals")
	game._resume()
	check(game.session_flow.clock.resume_ease == 0, "Manual resume restarts source easing")
	game.session_flow.advance(0.05)
	game.combat.model.damage_player(99999)
	game.combat._sync_model_to_vehicle()
	game.combat._publish()
	check(game.screen_state == "death" and paused and not game.vehicle.get_node("VehicleView").visible, "Lethal damage starts local destruction cinematic and hides player")
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == "death_started").size() == 1 and not events.any(func(event: Dictionary) -> bool: return event.kind == "result"), "Death FX starts once while final result is deferred")
	check(game.progression.contracts.active, "Contracts stay active until source death timer finishes")
	var elapsed: float = game.combat.model.elapsed
	var weather_elapsed: float = game.world.weather.elapsed
	for index in 47:
		game.session_flow.advance(0.05)
	check(game.screen_state == "death" and game.progression.contracts.active, "Result remains hidden before2.4 raw seconds")
	for index in 4:
		game.session_flow.advance(0.05)
	check(game.screen_state == "result" and not game.progression.contracts.active, "Death timer publishes result and closes contracts")
	check(game.camera.death_cinematic.elapsed >= 2.4 and game.session_flow.clock.effects_delta == 0.05, "After result, source cinematic orbit finishes and destruction effects continue fading")
	check(game.combat.model.elapsed == elapsed and game.world.weather.elapsed == weather_elapsed, "Only cinematic effects/camera advance during death")
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == "result").size() == 1, "Death summary and progression result are exactly once")
	game.run_seed_override = 991827
	game.restart_run()
	await game.run_prepared
	for index in 60:
		game.session_flow.advance(0.05)
	game.combat.model.damage_player(99999)
	game.combat._sync_model_to_vehicle()
	game.combat._publish()
	check(game.screen_state == "death", "Second run rearms death cinematic")
	var old_generation: int = game.combat.model.generation
	game.restart_run()
	check(game.session_flow.pending_result.is_empty() and game.session_flow.clock.phase == "idle", "Restart cancels pending previous death before asynchronous world rebuild")
	await game.run_prepared
	for index in 60:
		game.session_flow.advance(0.05)
	check(game.combat.model.generation > old_generation and game.screen_state == "running" and game.vehicle.get_node("VehicleView").visible, "New generation finishes intro with visible living player")
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == "result").size() == 1, "Canceled previous generation cannot later emit death result")
	game.queue_free()
	await process_frame
	paused = false
	print("Session flow: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
