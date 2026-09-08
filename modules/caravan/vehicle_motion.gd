extends RefCounted

const Handling = preload("res://modules/caravan/handling_rules.gd")
const MotionState = preload("res://modules/caravan/vehicle_motion_state.gd")

static func normalize_angle(value: float) -> float:
	return atan2(sin(value), cos(value))

static func damp(value: float, target: float, rate: float, delta: float) -> float:
	return value + (target - value) * (1.0 - exp(-rate * delta))

static func step(state: MotionState, controls: Dictionary, tuning: Dictionary, delta: float) -> float:
	var max_speed: float = maxf(0.001, tuning.get("base_maximum_speed", tuning["maximum_speed"]))
	var wheeled: bool = tuning.get("wheeled", false)
	var throttle: float = controls["throttle"]
	state.throttle = damp(state.throttle, throttle, (15.0 if throttle == 0.0 else 18.0) if wheeled else (5.2 if throttle == 0.0 else 7.5), delta)
	state.steer = damp(state.steer, controls["steer"], Handling.steer_response(state.speed) if wheeled else 9.5, delta)
	var parking_brake: bool = wheeled and controls["handbrake"]
	var target: float = state.throttle * max_speed * (0.46 if state.throttle < 0.0 else 1.0)
	if parking_brake:
		target = 0.0
	var reversing: bool = (state.speed > 1.0 and target < 0.0) or (state.speed < -1.0 and target > 0.0)
	var speed_ratio: float = clampf(absf(state.speed) / max_speed, 0.0, 1.0)
	var response: float = 2.8 if throttle == 0.0 else (float(tuning["braking"]) if reversing else float(tuning["acceleration"]) * (1.0 - speed_ratio * 0.38))
	if parking_brake:
		response = float(tuning["braking"])
	if wheeled and (throttle == 0.0 or reversing or parking_brake):
		response *= Handling.braking_factor(float(tuning.get("surface_traction", 1.0)), float(tuning.get("mass", Handling.BASE_MASS)))
	state.speed = move_toward(state.speed, target, response * delta)
	if absf(state.speed) < 0.015 and throttle == 0.0:
		state.speed = 0.0
	if tuning.get("nitro", false) and not parking_brake:
		state.speed = damp(state.speed, max_speed * (1.82 if tuning["fueled"] else 1.0), 8.5, delta)
	if tuning.get("ram", false) and not parking_brake:
		state.speed = damp(state.speed, max_speed * (1.14 if tuning["fueled"] else 1.0), 7.0, delta)
	var handbraking: bool = controls["handbrake"] and absf(state.speed) > 2.2
	var yaw: float = state.steer * 1.36 * clampf(absf(state.speed) / 2.4, 0.12, 1.0) * (1.0 if state.speed >= 0.0 else -1.0) * (1.0 - speed_ratio * 0.22) * (1.42 if handbraking else 1.0)
	if wheeled:
		var steering_angle := state.steer * Handling.MAX_STEERING_ANGLE / (1.0 + pow(absf(state.speed) / Handling.STEERING_SPEED, 2.0))
		yaw = state.speed / maxf(1.0, float(tuning.get("wheelbase", 4.7))) * tan(steering_angle) * (1.28 if handbraking else 1.0)
	state.yaw_velocity = damp(state.yaw_velocity, yaw, Handling.YAW_RESPONSE if wheeled else (5.5 if handbraking else 9.5), delta)
	state.heading = normalize_angle(state.heading + state.yaw_velocity * delta)
	var grip: float = ((2.0 if handbraking else 12.0 - speed_ratio * 2.0) if wheeled else (1.05 if handbraking else 4.8 - speed_ratio * 1.5)) * float(tuning["traction"])
	if wheeled:
		grip *= Handling.cornering_factor(float(tuning.get("surface_traction", 1.0)), float(tuning.get("mass", Handling.BASE_MASS)))
	state.move_heading = normalize_angle(state.move_heading + normalize_angle(state.heading - state.move_heading) * (1.0 - exp(-grip * delta)))
	state.slip_angle = normalize_angle(state.move_heading - state.heading)
	if handbraking:
		state.speed = move_toward(state.speed, 0.0, 0.62 * delta)
	state.x += sin(state.move_heading) * state.speed * delta
	state.z += cos(state.move_heading) * state.speed * delta
	return speed_ratio
