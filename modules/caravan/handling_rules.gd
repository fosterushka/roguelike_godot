extends RefCounted

const BASE_MASS := 12.0
const MAX_STEERING_ANGLE := 0.55
const STEERING_SPEED := 12.0
const LOW_SPEED_RESPONSE := 18.0
const HIGH_SPEED_RESPONSE := 10.0
const YAW_RESPONSE := 14.0
const MIN_BRAKING_GRIP := 0.34
const MIN_CORNERING_GRIP := 0.36
const MAX_MASS_RATIO := 2.5

static func steer_response(speed: float) -> float:
	return lerpf(LOW_SPEED_RESPONSE, HIGH_SPEED_RESPONSE, clampf(absf(speed) / STEERING_SPEED, 0.0, 1.0))

static func braking_factor(surface_traction: float, mass: float) -> float:
	var grip := clampf(surface_traction, 0.1, 1.0)
	var inertia := clampf(mass / BASE_MASS, 1.0, MAX_MASS_RATIO)
	return maxf(MIN_BRAKING_GRIP, grip * grip) / sqrt(inertia)

static func cornering_factor(surface_traction: float, mass: float) -> float:
	return maxf(MIN_CORNERING_GRIP, surface_traction * surface_traction) / sqrt(clampf(mass / BASE_MASS, 1.0, MAX_MASS_RATIO))
