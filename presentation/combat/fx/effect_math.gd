extends RefCounted

const ROCKET_EXPANSION := 2.45
const ROCKET_FADE_IN_RATIO := 0.12

static func fireball(life: float, duration: float = 0.52) -> Dictionary:
	var progress := clampf(1.0 - life / maxf(0.001, duration), 0.0, 1.0)
	var expansion := 1.0 - pow(1.0 - progress, 3.0)
	return {"progress": progress, "opacity": 1.0 - smoothstep(0.14, 1.0, progress), "width": 0.56 + expansion * 0.88, "height": 0.5 + expansion * 0.7, "light": pow(1.0 - progress, 3.0)}

static func rocket(age: float, life: float, scale_value: float, opacity: float) -> Dictionary:
	var ratio := clampf(age / maxf(0.0001, life), 0.0, 1.0)
	return {"opacity": opacity * minf(1.0, ratio / ROCKET_FADE_IN_RATIO) * (1.0 - ratio * ratio), "scale": scale_value * (1.0 + ratio * ROCKET_EXPANSION), "ratio": ratio}

static func sample_segment(start: Vector3, end: Vector3, carry: float, delta: float, maximum: int = 192) -> Dictionary:
	var distance := start.distance_to(end)
	if distance <= 0.00000001:
		return {"samples": [], "carry": carry}
	var first := 0.38 - carry if carry > 0.0 else 0.38
	var count := floori((distance - first) / 0.38) + 1 if first <= distance else 0
	var samples: Array[Dictionary] = []
	for index in range(maxi(0, count - maximum), count):
		var ratio := minf(1.0, (first + index * 0.38) / distance)
		samples.append({"position": start.lerp(end, ratio), "age": maxf(0.0, delta) * (1.0 - ratio)})
	return {"samples": samples, "carry": fposmod(carry + distance, 0.38)}

static func impact(distance: float, radius: float, power: float) -> float:
	if distance >= radius or radius <= 0.0:
		return 0.0
	var strength := power * pow(1.0 - maxf(0.0, distance) / radius, 2.0)
	return strength if strength >= 0.02 else 0.0
