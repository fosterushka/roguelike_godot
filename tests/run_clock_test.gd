extends "res://tests/world_generation_test.gd"
const Clock = preload("res://modules/session/run_clock.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/run_clock.json"))
	for fixture: Dictionary in fixtures:
		var clock := Clock.new()
		if fixture.name == "intro_resume":
			clock.begin_run()
		else:
			clock.phase = "running"
		var countdown := []
		for frame: Dictionary in fixture.frames:
			match str(frame.action):
				"pause": clock.pause()
				"resume": clock.resume()
				"impact": clock.request_hit_stop(0.7)
				"death": clock.begin_death()
			var update := clock.step(frame.delta)
			if update.countdown_changed:
				countdown.append(clock.intro_step)
			compare(clock.simulation_delta, frame.simulation, fixture.name + " simulation", 0.000000001)
			compare(clock.intro_remaining, frame.intro, "countdown seconds", 0.000000001)
			compare(clock.intro_step, frame.introStep, "source step")
			compare(clock.resume_ease, frame.resume, "source smoothstep input", 0.000000001)
			compare(clock.hit_stop, frame.hitStop, "raw hitstop expiry", 0.000000001)
			compare(clock.weather_delta, frame.weather, "weather remains raw", 0.000000001)
			compare(clock.phase == "result", frame.ended, "delayed terminal timing")
			compare(countdown, frame.countdown, "source countdown transitions")
			if frame.deathElapsed > 0:
				compare(clock.effects_delta, minf(frame.delta, 0.05) * frame.deathScale, "source effects keep fading behind result", 0.000000001)
			if clock.phase == "death":
				compare(clock.death_elapsed, frame.deathElapsed, "cinematic raw elapsed", 0.000000001)
				compare(Clock.death_scale(clock.death_elapsed), frame.deathScale, "cinematic .22 recovery", 0.000000001)
	clock_cancellation()
	print("Run clock: %d checks, %d failures, 540 source frames" % [checks, failures])
	quit(0 if failures == 0 else 1)

func clock_cancellation() -> void:
	var clock := Clock.new()
	clock.begin_run()
	clock.step(0.05)
	clock.cancel()
	clock.step(0.05)
	compare(clock.phase, "idle", "cancel removes countdown")
	compare(clock.simulation_delta, 0.0, "cancel freezes gameplay")
	clock.begin_run()
	clock.begin_death()
	clock.step(0.05)
	clock.begin_run()
	compare(clock.death_elapsed, 0.0, "new run removes cinematic clock")
	compare(clock.intro_remaining, 2.65, "new run restores full intro")
