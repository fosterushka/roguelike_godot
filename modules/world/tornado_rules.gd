extends RefCounted
const Weather = preload("res://modules/world/weather_rules.gd")
const INFLUENCE_RADIUS := 17.0
const DANGER_RADIUS := 3.6
const CAMERA_DUST_RADIUS := 11.0
const FADE_IN := 2.4
const FADE_OUT := 3.2
var intensity := 0.0
var position := Vector3.ZERO
var age := 0.0

func step(seed: int, phase: Dictionary, elapsed: float, delta: float) -> void:
	var active: bool = phase.type == "storm"
	intensity = move_toward(intensity, 1.0 if active else 0.0, delta / (FADE_IN if active else FADE_OUT))
	if not active:
		age += delta
		return
	age = elapsed - float(phase.starts_at)
	var progress := clampf(age / float(phase.duration), 0.0, 1.0)
	var angle := Weather.unit(seed, phase.index, 0x2e84ad) * TAU
	var distance := 32.0 + Weather.unit(seed, phase.index, 0x71c35b) * 16.0
	var drift := 0.35 + Weather.unit(seed, phase.index, 0x48b12f) * 0.3
	distance += (1088.0 - distance) * (0.5 - cos(progress * TAU) * 0.5)
	angle += progress * TAU * (0.68 + drift * 0.24)
	position = Vector3(cos(angle) * distance, 0, sin(angle) * distance)

func influence(point: Vector3) -> Dictionary:
	var offset := position - point
	offset.y = 0
	var distance := offset.length()
	if distance >= INFLUENCE_RADIUS or intensity <= 0:
		return {"strength": 0.0, "core": false, "dust": 0.0, "force": Vector3.ZERO}
	var direction := offset / maxf(0.001, distance)
	var radial := 1.0 - distance / INFLUENCE_RADIUS
	var strength := smoothstep(0.0, 1.0, radial) * intensity
	return {"strength": strength, "core": distance <= DANGER_RADIUS and intensity >= 0.68,
		"dust": (1.0 - smoothstep(DANGER_RADIUS * 0.45, CAMERA_DUST_RADIUS, distance)) * intensity,
		"force": Vector3(direction.x * 5.2 - direction.z * 8.4, 0, direction.z * 5.2 + direction.x * 8.4) * strength}
