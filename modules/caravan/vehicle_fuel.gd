extends RefCounted

const KPH_PER_MPS: float = 3.6
const BASE_MAXIMUM_SPEED_KPH: float = 50.0
const BASE_MAXIMUM_SPEED: float = BASE_MAXIMUM_SPEED_KPH / KPH_PER_MPS
const BASE_LEVEL: int = 1
const BASE_WEIGHT: float = 12.0
const LEVEL_SPEED_BONUS: float = 0.18
const WEIGHT_SPEED_PENALTY: float = 0.105
const MINIMUM_SPEED: float = 4.2
const MOMENTUM_SPEED_BONUS: float = 0.08
const BASE_ACCELERATION: float = 6.7
const BASE_BRAKING: float = 15.5
const CAPACITY: float = 100.0
const BURN_PER_SECOND: float = 0.45
const EMPTY_SPEED_MULTIPLIER: float = 0.35

static func drive_tuning(fuel: float, stats: Dictionary = {}) -> Dictionary:
	var multiplier: float = 1.0 if fuel > 0.0 else EMPTY_SPEED_MULTIPLIER
	return {
		"maximum_speed": maximum_speed(fuel, stats),
		"acceleration": BASE_ACCELERATION * multiplier * float(stats.get("speed_mult", 1.0)) * float(stats.get("motor_acceleration_mult", 1.0)),
		"braking": BASE_BRAKING * float(stats.get("speed_mult", 1.0)),
		"traction": float(stats.get("traction", 1.0)),
		"fueled": fuel > 0.0,
		"nitro": float(stats.get("nitro_timer", 0.0)) > 0.0,
		"ram": float(stats.get("ram_timer", 0.0)) > 0.0,
	}

static func maximum_speed(fuel: float, stats: Dictionary = {}) -> float:
	var engine_speed := BASE_MAXIMUM_SPEED + BASE_WEIGHT * WEIGHT_SPEED_PENALTY
	engine_speed += (float(stats.get("level", BASE_LEVEL)) - BASE_LEVEL) * LEVEL_SPEED_BONUS
	engine_speed *= float(stats.get("speed_mult", 1.0)) * float(stats.get("motor_speed_mult", 1.0))
	var loaded_speed := maxf(MINIMUM_SPEED, engine_speed - float(stats.get("weight", BASE_WEIGHT)) * WEIGHT_SPEED_PENALTY)
	return loaded_speed * (1.0 + float(stats.get("momentum", 0.0)) * MOMENTUM_SPEED_BONUS) * (1.0 if fuel > 0.0 else EMPTY_SPEED_MULTIPLIER)

static func consume(current: float, maximum: float, speed: float, throttle: float, delta: float, burn_multiplier: float = 1.0) -> float:
	if delta <= 0.0 or absf(speed) < 0.15:
		return current
	current = clampf(current, 0.0, maxf(1.0, maximum))
	var movement_load: float = clampf(absf(speed) / 6.0, 0.25, 1.5)
	var throttle_load: float = clampf(absf(throttle), 0.35, 1.0)
	return current - minf(current, BURN_PER_SECOND * burn_multiplier * movement_load * throttle_load * delta)
