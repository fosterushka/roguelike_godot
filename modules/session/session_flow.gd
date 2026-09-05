extends Node

const Locale = preload("res://presentation/ui/ui_locale.gd")
const Clock = preload("res://modules/session/run_clock.gd")
var clock := Clock.new()
var game: Node3D
var pending_result: Dictionary = {}
var generation := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -1000

func setup(application: Node3D) -> void:
	game = application

func simulation_delta() -> float:
	return clock.simulation_delta

func effects_delta(_raw: float = 0.0) -> float:
	return clock.effects_delta

func begin_run() -> void:
	pending_result.clear()
	generation = game.combat.model.generation
	game.world.prepare_run_actors()
	clock.begin_run()
	game.vehicle.get_node("VehicleView").visible = true
	game.camera.death_cinematic.clear()
	game._set_screen("countdown")
	game.hud.set_countdown(3, true)

func cancel() -> void:
	pending_result.clear()
	clock.cancel()
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_countdown(0, false)
		if is_instance_valid(game.camera):
			game.camera.death_cinematic.clear()

func defer_result(event: Dictionary) -> bool:
	if event.get("won", false) or event.get("extracted", false):
		clock.finish()
		return false
	if not pending_result.is_empty() or not clock.begin_death():
		return false
	pending_result = event.duplicate(true)
	generation = int(event.get("generation", game.combat.model.generation))
	game.world.activities.cancel_all("player destroyed")
	game._set_screen("death")
	game.hud.set_countdown(0, false)
	game.vehicle.motion.speed = 0
	game.vehicle.velocity = Vector3.ZERO
	game.combat.model.player.speed = 0
	game.camera.death_cinematic = {"position": game.vehicle.global_position, "heading": game.vehicle.motion.heading, "elapsed": 0.0, "duration": Clock.DEATH_SECONDS}
	game.combat.combat_event.emit({"kind": "death_started", "generation": generation, "position": game.vehicle.global_position, "heading": game.vehicle.motion.heading})
	game.vehicle.get_node("VehicleView").visible = false
	game.hud.set_status(Locale.text("КАРАВАН УНИЧТОЖЕН"))
	return true

func _physics_process(raw: float) -> void:
	advance(raw)

func advance(raw: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.combat):
		return
	var update := clock.step(raw)
	if clock.weather_delta > 0.0:
		game.world.update_weather_raw(clock.weather_delta)
	if clock.ambient_delta > 0.0:
		game.world.step_ambient(clock.ambient_delta)
	if update.countdown_changed:
		game.hud.set_countdown(clock.intro_step, true)
		if clock.intro_step == 0:
			game.sound.play_cue("countdownGo", true)
	if update.countdown_finished:
		game.hud.finish_countdown()
		game._set_screen("running")
		game.hud.show_world_banner(Locale.text("ВОЛНА 1"), Locale.text("Собирайте лом и развивайте арсенал"))
		game.run_ready.emit(game.run_seed)
	if clock.phase in ["death", "result"] and not game.camera.death_cinematic.is_empty():
		game.camera.death_cinematic.elapsed = clock.death_elapsed
		if is_instance_valid(game.combat_view._effects):
			game.combat_view._effects.advance_cinematic(clock.effects_delta)
	if update.death_finished and not pending_result.is_empty():
		var result := pending_result
		pending_result = {}
		if int(result.get("generation", -1)) == game.combat.model.generation:
			game.combat.deliver_result(result)
