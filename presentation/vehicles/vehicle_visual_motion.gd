extends RefCounted
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const Fuel = preload("res://modules/caravan/vehicle_fuel.gd")

static func target_scale(level: int) -> float:
	return Dimensions.target_scale(level)

static func trailer(pose: Dictionary, leader: Dictionary, delta: float, distance: float) -> void:
	if delta <= 0.0:
		return
	var scale_value := float(leader.get("scale", 0.88))
	var rear_hitch := float(leader.get("rear_hitch", 3.78)) * scale_value
	var hitch := Vector2(leader.x - sin(leader.heading) * rear_hitch, leader.z - cos(leader.heading) * rear_hitch)
	var front_offset := 1.55 * scale_value
	var drawbar_length := 1.7 * scale_value
	var previous := Vector2(pose.x, pose.z)
	var forward := Vector2(sin(pose.heading), cos(pose.heading))
	var old_front := previous + forward * front_offset
	var old_rear := previous - forward * front_offset
	var drawbar_direction := (hitch - old_front).normalized()
	if drawbar_direction.is_zero_approx():
		drawbar_direction = forward
	var front := hitch - drawbar_direction * drawbar_length
	var body_direction := (front - old_rear).normalized()
	if body_direction.is_zero_approx():
		body_direction = forward
	var rear := front - body_direction * front_offset * 2
	var center := (front + rear) * 0.5
	var desired := atan2(body_direction.x, body_direction.y)
	pose.yaw_rate = wrapf(desired - pose.heading, -PI, PI) / delta
	pose.heading = desired
	pose.x = center.x
	pose.z = center.y
	pose.speed = (center - previous).dot(body_direction) / delta
	pose.steer = clampf(wrapf(atan2(drawbar_direction.x, drawbar_direction.y) - desired, -PI, PI) / 0.55, -1.0, 1.0)
	pose.hitch = hitch
	pose.front_axle = front
	pose.rear_axle = rear
	pose.tow_distance = distance

static func aim_angles(origin: Vector3, target: Vector3) -> Vector2:
	var direction := target - origin
	return Vector2(atan2(direction.x, direction.z), clampf(-atan2(direction.y, maxf(0.0001, Vector2(direction.x, direction.z).length())), -PI * 0.27, PI * 0.27))

static func body(state: Dictionary, player: Dictionary, delta: float) -> void:
	var speed: float = player.get("speed", 0.0)
	var max_speed := Fuel.maximum_speed(float(player.get("fuel", Fuel.CAPACITY)), player)
	var amount := clampf(absf(speed) / maxf(max_speed, 1.0), 0.0, 1.7)
	var acceleration: float = (speed - state.last_speed) / maxf(delta, 0.001)
	state.last_speed = speed
	var pitch: float = clampf(-acceleration * 0.008, -0.14, 0.14) + (-0.07 if player.get("nitro_timer", 0.0) > 0.0 else 0.0) + (-0.025 if player.get("ram_timer", 0.0) > 0.0 else 0.0) + state.impact_pitch
	var roll: float = clampf(-player.get("steer", 0.0) * amount * 0.095 - player.get("slip_angle", 0.0) * 0.13, -0.145, 0.145) + state.impact_roll
	var smooth := 1.0 - pow(0.00014, delta)
	state.pitch = lerpf(state.pitch, pitch, smooth)
	state.roll = lerpf(state.roll, roll, smooth)
	state.impact_pitch *= pow(0.018, delta)
	state.impact_roll *= pow(0.015, delta)
	state.elapsed += delta
	state.bob = 0.0
	state.speed_amount = amount
	state.wheel_angle += speed * delta * 0.9
	state.wheel_phase = state.elapsed * (9.0 + amount * 5.0)
