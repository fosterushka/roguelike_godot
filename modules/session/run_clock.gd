extends RefCounted

const INTRO_SECONDS := 2.65
const DEATH_SECONDS := 2.4
var phase := "idle"
var intro_remaining := 0.0
var intro_step := -1
var resume_ease := 1.0
var hit_stop := 0.0
var death_elapsed := 0.0
var death_remaining := 0.0
var simulation_delta := 0.0
var raw_delta := 0.0
var effects_delta := 0.0
var weather_delta := 0.0
var ambient_delta := 0.0

func begin_run() -> void:
	phase = "countdown"
	intro_remaining = INTRO_SECONDS
	intro_step = -1
	resume_ease = 0.0
	hit_stop = 0.0
	death_elapsed = 0.0
	death_remaining = 0.0
	_clear_deltas()

func cancel() -> void:
	phase = "idle"
	intro_remaining = 0.0
	death_elapsed = 0.0
	death_remaining = 0.0
	hit_stop = 0.0
	_clear_deltas()

func pause() -> void:
	if phase == "running":
		phase = "paused"
	_clear_deltas()

func resume() -> void:
	if phase == "paused":
		phase = "running"
		resume_ease = 0.0

func begin_death() -> bool:
	if phase not in ["running", "paused", "countdown"]:
		return false
	phase = "death"
	intro_remaining = 0.0
	death_elapsed = 0.0
	death_remaining = DEATH_SECONDS
	_clear_deltas()
	return true

func finish() -> void:
	phase = "result"
	_clear_deltas()

func request_hit_stop(power: float) -> void:
	hit_stop = maxf(hit_stop, minf(0.075, 0.014 + power * 0.045))

static func death_scale(elapsed: float) -> float:
	if elapsed >= DEATH_SECONDS:
		return 1.0
	var recovery := clampf((elapsed / DEATH_SECONDS - 0.62) / 0.38, 0, 1)
	return 0.22 + recovery * recovery * (3.0 - 2.0 * recovery) * 0.78

func step(delta: float) -> Dictionary:
	_clear_deltas()
	raw_delta = clampf(delta, 0.0, 0.05)
	var update := {"countdown_changed": false, "countdown_finished": false, "death_finished": false}
	if phase == "death":
		death_elapsed += raw_delta
		death_remaining = maxf(0.0, death_remaining - raw_delta)
		if death_remaining == 0.0:
			phase = "result"
			update.death_finished = true
		effects_delta = raw_delta * death_scale(death_elapsed)
	elif phase == "result" and death_elapsed > 0.0:
		death_elapsed += raw_delta
		effects_delta = raw_delta
	elif phase == "countdown":
		intro_remaining = maxf(0.0, intro_remaining - raw_delta)
		var next_step := 3 if intro_remaining > 1.92 else 2 if intro_remaining > 1.25 else 1 if intro_remaining > 0.58 else 0
		update.countdown_changed = next_step != intro_step
		intro_step = next_step
		weather_delta = raw_delta
		ambient_delta = raw_delta * 0.25
		if intro_remaining == 0.0:
			phase = "running"
			resume_ease = 0.0
			update.countdown_finished = true
	elif phase == "running":
		resume_ease = minf(1.0, resume_ease + raw_delta * 2.8)
		simulation_delta = raw_delta * resume_ease * resume_ease * (3.0 - 2.0 * resume_ease)
		weather_delta = raw_delta
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - raw_delta)
		simulation_delta = 0.0
	if phase == "running":
		effects_delta = simulation_delta
	return update

func _clear_deltas() -> void:
	simulation_delta = 0.0
	raw_delta = 0.0
	effects_delta = 0.0
	weather_delta = 0.0
	ambient_delta = 0.0
