extends RefCounted
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Rules = preload("res://modules/world/weather_rules.gd")
var seed_value := 72841
var elapsed := 0.0
var phase: Dictionary = {}
var mud_zones: Array[Dictionary] = []
var next_mud_id := 1
var strike_index := 0
var next_strike := 0.0
var events: Array[Dictionary] = []
var traction := 1.0
var traction_from := 1.0
var transition_elapsed := 0.0

func reset(seed: int) -> void:
	seed_value = seed
	elapsed = 0.0
	traction = 1.0
	traction_from = 1.0
	transition_elapsed = 0.0
	phase = Rules.phase_at(seed, elapsed)
	mud_zones.clear()
	next_mud_id = 1
	strike_index = 0
	next_strike = phase.starts_at + Rules.lightning_sample(seed, phase.index, 0).delay
	events.clear()

func step(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	if phase.is_empty() or elapsed >= float(phase.ends_at):
		phase = Rules.phase_at(seed_value, elapsed)
		traction_from = float(Rules.TRACTION.get(str(phase.get("previous_type", "sunny")), 1.0))
		strike_index = 0
		next_strike = phase.starts_at + Rules.lightning_sample(seed_value, phase.index, 0).delay
		events.append({"kind": "weather_changed", "type": phase.type})
	transition_elapsed = clampf(elapsed - float(phase.get("starts_at", 0)), 0, 12.0)
	var linear := transition_elapsed / 12.0
	var blend := linear * linear * (3.0 - 2.0 * linear)
	traction = lerpf(traction_from, float(Rules.TRACTION.get(str(phase.type), 1.0)), blend)
	while elapsed >= next_strike:
		var sample := Rules.lightning_sample(seed_value, phase.index, strike_index)
		if phase.type == "storm" and elapsed - next_strike <= 1.0:
			events.append({"kind": "lightning_due", "sample": sample})
		strike_index += 1
		next_strike += Rules.lightning_sample(seed_value, phase.index, strike_index).delay
	mud_zones = mud_zones.filter(func(zone: Dictionary) -> bool: return zone.expires_at > elapsed)

func create_mud(point: Vector3) -> bool:
	if not Rules.wet(str(phase.type)):
		return false
	if mud_zones.size() >= Rules.MAX_MUD_ZONES:
		mud_zones.pop_front()
	point.y = Terrain.height_at(point.x, point.z)
	mud_zones.append({"id": next_mud_id, "position": point, "radius": Rules.MUD_RADIUS, "expires_at": elapsed + Rules.MUD_DURATION})
	next_mud_id += 1
	return true

func visual_mix() -> Vector4:
	return Rules.mix_for_phase(phase, elapsed)

func surface_at(point: Vector3, airborne: bool = false) -> Dictionary:
	var muddy := false
	if not airborne:
		for zone in mud_zones:
			if Vector2(point.x - zone.position.x, point.z - zone.position.z).length_squared() <= Rules.MUD_RADIUS * Rules.MUD_RADIUS:
				muddy = true
				break
	return {"traction": traction, "movement": Rules.MUD_MOVEMENT if muddy else 1.0, "turn": Rules.MUD_TURN if muddy else 1.0}

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate()
	events.clear()
	return result
