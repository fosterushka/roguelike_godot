extends RefCounted

const Customization = preload("res://modules/caravan/vehicle_customization.gd")
const Weather = preload("res://modules/world/weather_rules.gd")
const LOCAL_DETECTION_RANGE := 40.0
const BEAM_EDGE_RATIO := 0.22
const RANGE_EDGE_RATIO := 0.2

static func lamp_coverage(player: Dictionary, point: Vector3) -> float:
	if not player.get("customization", {}).get("fog_lamps", false):
		return 0.0
	var definition: Dictionary = Customization.FOG_LAMPS
	var origin: Vector3 = player.get("position", Vector3.ZERO)
	var offset := Vector2(point.x - origin.x, point.z - origin.z)
	var distance := offset.length()
	var reach := float(definition.range)
	if distance >= reach:
		return 0.0
	var near_radius := float(definition.near_radius)
	var heading := float(player.get("heading", 0.0))
	var angle := acos(clampf(offset.normalized().dot(Vector2(sin(heading), cos(heading))), -1.0, 1.0)) if distance > 0.0 else 0.0
	var half_angle := deg_to_rad(float(definition.half_angle_deg))
	var cone := 1.0 - smoothstep(half_angle * (1.0 - BEAM_EDGE_RATIO), half_angle, angle)
	var local := 1.0 - smoothstep(near_radius * 0.5, near_radius, distance)
	var end := 1.0 - smoothstep(reach * (1.0 - RANGE_EDGE_RATIO), reach, distance)
	return maxf(cone, local) * end * float(definition.strength)

static func range_multiplier(player: Dictionary, point: Vector3, fog_strength: float, radar: bool = false) -> float:
	return Weather.visibility_multiplier(fog_strength * (1.0 - lamp_coverage(player, point)), radar)

static func detects(player: Dictionary, point: Vector3, fog_strength: float) -> bool:
	var origin: Vector3 = player.get("position", Vector3.ZERO)
	return Vector2(point.x - origin.x, point.z - origin.z).length() <= LOCAL_DETECTION_RANGE * range_multiplier(player, point, fog_strength)
