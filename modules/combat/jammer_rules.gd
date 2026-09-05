extends RefCounted

const RADIUS := 48.0
const FULL_RADIUS := 24.0
const PULSE_PERIOD := 3.2
const PULSE_START := 1.6
const PULSE_DURATION := 0.5
const PULSE_EDGE := 0.12
const MAX_SPREAD := PI / 30.0
var age := 0.0
var seed_value := 0

func reset(player: Dictionary, seed: int = 0) -> void:
	age = 0.0
	seed_value = seed
	clear_player(player)

static func clear_player(player: Dictionary) -> void:
	player.merge({"jammed": false, "jammer_strength": 0.0, "jammer_reversed": false,
		"jammer_pulse": 0.0, "jammer_source_id": -1, "jammer_source_position": Vector3.ZERO,
		"jammer_radius": RADIUS}, true)

static func source(player: Dictionary, enemies: Array) -> Dictionary:
	if float(player.get("hp", 1.0)) <= 0:
		return {}
	var best: Dictionary = {}
	var nearest := RADIUS * RADIUS
	for enemy: Dictionary in enemies:
		if enemy.get("kind", "") != "jammerTruck" or enemy.get("dead", false) or float(enemy.get("hp", 1)) <= 0 or float(enemy.get("stagger_remaining", 0)) > 0 or enemy.get("allegiance", "enemy") != "enemy" or not enemy.get("counts_as_hostile", true):
			continue
		var offset: Vector3 = enemy.position - Vector3(player.get("position", Vector3.ZERO))
		var distance := Vector2(offset.x, offset.z).length_squared()
		if distance < nearest or (distance == nearest and (best.is_empty() or int(enemy.get("id", 0)) < int(best.get("id", 0)))):
			best = enemy
			nearest = distance
	return best

func step(player: Dictionary, enemies: Array[Dictionary], delta: float) -> void:
	var emitter := source(player, enemies)
	var active := not emitter.is_empty()
	var target := 0.0
	if active:
		var offset: Vector3 = emitter.position - player.position
		var proximity := clampf((RADIUS - Vector2(offset.x, offset.z).length()) / (RADIUS - FULL_RADIUS), 0, 1)
		target = smoothstep(0.0, 1.0, proximity)
		player.jammer_source_id = int(emitter.get("id", -1))
		player.jammer_source_position = emitter.position
		age += maxf(0, delta)
	else:
		age = 0.0
	var strength := lerpf(float(player.get("jammer_strength", 0)), target, 1.0 - exp(-maxf(0, delta) / (0.45 if active else 0.25)))
	if not active and strength < 0.001:
		strength = 0.0
		player.jammer_source_id = -1
		player.jammer_source_position = Vector3.ZERO
	player.jammed = active
	player.jammer_radius = RADIUS
	player.jammer_strength = strength
	player.jammer_pulse = pulse_at(age) if active else 0.0
	player.jammer_reversed = input_gain(player) < 0.0

static func pulse_at(elapsed: float) -> float:
	var phase := fposmod(elapsed, PULSE_PERIOD) - PULSE_START
	if phase <= 0 or phase >= PULSE_DURATION:
		return 0.0
	return smoothstep(0.0, PULSE_EDGE, phase) * (1.0 - smoothstep(PULSE_DURATION - PULSE_EDGE, PULSE_DURATION, phase))

static func input_gain(player: Dictionary) -> float:
	if not player.get("jammed", false):
		return 1.0
	return 1.0 - clampf(float(player.get("jammer_strength", 0)), 0, 1) * (0.1 + 1.8 * clampf(float(player.get("jammer_pulse", 0)), 0, 1))

static func controls(input: Dictionary, player: Dictionary) -> Dictionary:
	var result := input.duplicate()
	var gain := input_gain(player)
	result.throttle = float(input.get("throttle", 0)) * gain
	result.steer = float(input.get("steer", 0)) * gain
	return result

func aim(origin: Vector3, target: Vector3, player: Dictionary, shot_id: int) -> Vector3:
	if not player.get("jammed", false):
		return target
	# A shot-index hash gives deterministic dispersion without consuming combat RNG.
	var hash_value := (shot_id * 1103515245 + seed_value * 12345 + 1013904223) & 0x7fffffff
	hash_value = ((hash_value ^ (hash_value >> 16)) * 1103515245 + 12345) & 0x7fffffff
	var angle := (float(hash_value) / 2147483647.0 * 2.0 - 1.0) * MAX_SPREAD * clampf(float(player.get("jammer_strength", 0)), 0, 1)
	return origin + (target - origin).rotated(Vector3.UP, angle)
