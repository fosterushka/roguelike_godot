extends SceneTree

const Main = preload("res://app/main.tscn")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/caravan_presentation_%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	_check(game.sound.streams.size() == 42 and game.sound.voices.size() == 16, "All 42 original sound recipes preload into a bounded 16-voice pool")
	_check(game.sound.accepted_events == 0 and not game.sound.running, "Loading warmup is silent and gameplay audio remains stopped at menu")
	var total_samples := 0
	for stream: AudioStreamWAV in game.sound.streams.values():
		_check(stream != null and stream.mix_rate == 44100 and stream.data.size() > 1000, "Each procedural cue is decoded 44.1kHz PCM before gameplay")
		total_samples += stream.data.size()
	_check(total_samples > 1000000, "Prepared soundbank contains full original layered recipes")
	await game.restart_run()
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_recipes.json"))
	_check(recipes.recipes.mineHack == [{"kind": "tone", "frequency": 620.0, "duration": 0.12, "type": "square", "gain": 0.025, "slide": 90.0, "delay": 0.0, "filter": 0.0}], "Mine hack recipe preserves original source tone")
	var hack_voice: int = game.sound._cursor
	game.sound.on_combat_event({"kind": "mine_hacked"})
	_check(game.sound.voices[hack_voice].stream == game.sound.streams.mineHack, "Successful mine hack selects its own source cue")
	_check(game.sound.play_cue("shot_rocket"), "Gameplay event accepts source rocket cue")
	_check(not game.sound.play_cue("shot_bullet"), "Shot family enforces source 42ms cooldown across projectile types")
	game._toggle_pause()
	_check(not game.sound.running and not game.sound._engine.playing, "Pause stops engine and gameplay voices")
	_check(not game.sound.play_cue("explosion") and game.sound.play_cue("module", true), "Pause blocks gameplay sound while allowing UI upgrade feedback")
	game._toggle_sound()
	_check(not game.sound.enabled and not game.progression.profile.settings.soundEnabled, "Mute control updates persistent profile setting")
	_check(not game.sound.play_cue("evolve", true), "Muted settings also silence UI sounds")
	_check(game.progression.flush(), "Audio settings save to isolated profile")
	game._toggle_sound()
	game._resume()
	var before: float = game.camera.half_height
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	game.camera._unhandled_input(event)
	_check(game.camera.half_height == before - 2, "Wheel zoom uses source two-unit steps")
	for repeat in 30:
		game.camera._unhandled_input(event)
	_check(game.camera.half_height == 24, "Zoom in respects source minimum24")
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for repeat in 30:
		game.camera._unhandled_input(event)
	_check(game.camera.half_height == 48, "Zoom out respects source maximum48")
	game.camera.add_shake(0.5)
	game.camera._process(0.1)
	_check(game.camera.shake < 0.5 and game.camera.shake > 0, "Camera trauma decays smoothly using source rate")
	game.combat.model.player.coins = 1000
	game.combat.model.player.level = 4
	game.combat.buy_upgrade("trailer")
	var view = game.vehicle.get_node("VehicleView")
	_check(view._trailers.size() == 1 and view._trailers.values()[0].get_child_count() > 0, "Bought trailer uses exported source geometry")
	game.combat.model.spawn_enemy("shooter", Vector3(5, 0, 8))
	game.combat._publish()
	_check(game.combat_view._active_counts.drone > 0, "Shooter drone maps to original flying model")
	game.queue_free()
	await process_frame
	paused = false
	print("Presentation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
