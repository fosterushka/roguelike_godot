extends RefCounted

const BASE_MAXIMUM_SPEED: float = 8.33
const BASE_ACCELERATION: float = 6.7
const BASE_BRAKING: float = 15.5
const CAPACITY: float = 100.0
const BURN_PER_SECOND: float = 0.45
const EMPTY_SPEED_MULTIPLIER: float = 0.35

static func drive_tuning(fuel: float, stats: Dictionary = {}) -> Dictionary:
	var multiplier: float = 1.0 if fuel > 0.0 else EMPTY_SPEED_MULTIPLIER
	return {
		"maximum_speed": maxf(4.2, (9.2 + float(stats.get("level", 1)) * 0.18) * float(stats.get("speed_mult", 1.0)) * float(stats.get("motor_speed_mult", 1.0)) - float(stats.get("weight", 12)) * 0.105) * (1.0 + float(stats.get("momentum", 0.0)) * 0.08) * multiplier,
		"acceleration": BASE_ACCELERATION * multiplier * float(stats.get("speed_mult", 1.0)) * float(stats.get("motor_acceleration_mult", 1.0)),
		"braking": BASE_BRAKING * float(stats.get("speed_mult", 1.0)),
		"traction": float(stats.get("traction", 1.0)),
		"fueled": fuel > 0.0,
		"nitro": float(stats.get("nitro_timer", 0.0)) > 0.0,
		"ram": float(stats.get("ram_timer", 0.0)) > 0.0,
	}

static func consume(current: float, maximum: float, speed: float, throttle: float, delta: float, burn_multiplier: float = 1.0) -> float:
	if delta <= 0.0 or absf(speed) < 0.15:
		return current
	current = clampf(current, 0.0, maxf(1.0, maximum))
	var movement_load: float = clampf(absf(speed) / 6.0, 0.25, 1.5)
	var throttle_load: float = clampf(absf(throttle), 0.35, 1.0)
	return current - minf(current, BURN_PER_SECOND * burn_multiplier * movement_load * throttle_load * delta)
