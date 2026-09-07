extends RefCounted

const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const FRONT_Z := Dimensions.WHEEL_FRONT_Z
const REAR_Z := -Dimensions.WHEEL_FRONT_Z
const HALF_TRACK := Dimensions.WHEEL_HALF_TRACK
const RADIUS := 0.88
const ANCHORS := [Vector3(-HALF_TRACK, 0, FRONT_Z), Vector3(HALF_TRACK, 0, FRONT_Z), Vector3(-HALF_TRACK, 0, REAR_Z), Vector3(HALF_TRACK, 0, REAR_Z)]
const TRAVEL := 0.48
const PITCH_PER_ACCELERATION := 0.007
const MAX_LOAD_PITCH := 0.055
const PITCH_SPRING := 100.0
const PITCH_DAMPING := 20.0
const INTEGRATION_HZ := 120.0
const TRAILER_PITCH_FACTOR := 0.65

static func create() -> Dictionary:
	return {"initialized": false, "height": 0.0, "velocity": 0.0, "pitch": 0.0, "roll": 0.0, "pitch_velocity": 0.0, "roll_velocity": 0.0, "last_speed": 0.0, "wheel_offsets": PackedFloat32Array([0, 0, 0, 0]), "wheel_contacts": [true, true, true, true], "contacts": 4, "grip": 1.0, "slope": 0.0}

static func step(state: Dictionary, position: Vector3, heading: float, speed: float, _yaw_rate: float, delta: float, scale_value: float = 1.0, trailer: bool = false, sampler: Callable = Terrain.height_at) -> void:
	if delta <= 0.0:
		return
	var anchors := wheel_anchors(trailer)
	var grounds := PackedFloat32Array()
	var basis := Basis(Vector3.UP, heading)
	var scale_factor := maxf(0.1, scale_value)
	var average := 0.0
	for anchor: Vector3 in anchors:
		var point := position + basis * anchor * scale_factor
		var height := float(sampler.call(point.x, point.z))
		grounds.append(height)
		average += height * 0.25
	if not state.initialized:
		state.height = average
		state.last_speed = speed
		state.initialized = true
	var wheelbase: float = (anchors[0].z - anchors[2].z) * scale_factor
	var target_pitch := -atan2((grounds[0] + grounds[1] - grounds[2] - grounds[3]) * 0.5, wheelbase)
	var acceleration := (speed - float(state.last_speed)) / delta
	var load_pitch := clampf(-acceleration * PITCH_PER_ACCELERATION, -MAX_LOAD_PITCH, MAX_LOAD_PITCH)
	if trailer:
		load_pitch *= TRAILER_PITCH_FACTOR
	state.last_speed = speed
	state.slope = -sin(target_pitch)
	state.roll = 0.0
	state.roll_velocity = 0.0
	var steps := maxi(1, ceili(delta * INTEGRATION_HZ))
	var dt := delta / steps
	for substep in steps:
		state.pitch_velocity += ((load_pitch - float(state.pitch)) * PITCH_SPRING - float(state.pitch_velocity) * PITCH_DAMPING) * dt
		state.pitch = clampf(float(state.pitch) + float(state.pitch_velocity) * dt, -MAX_LOAD_PITCH, MAX_LOAD_PITCH)
		var force := 0.0
		var contacts := 0
		for index in 4:
			var mount_height: float = state.height
			var displacement := grounds[index] - mount_height
			var compression := 0.218 + displacement
			state.wheel_contacts[index] = displacement >= -TRAVEL * scale_factor and compression > 0.0
			if state.wheel_contacts[index]:
				contacts += 1
				force += maxf(0.0, 45.0 * compression - 13.5 * state.velocity) * 0.25
			state.wheel_offsets[index] = clampf(displacement / scale_factor, -TRAVEL, TRAVEL)
		state.contacts = contacts
		state.velocity += (force - 9.81) * dt
		state.height += state.velocity * dt
		state.height = maxf(state.height, average - TRAVEL * scale_factor)
	state.grip = lerpf(float(state.grip), clampf(float(state.contacts) / 4.0 * (1.0 - absf(state.velocity) * 0.065), 0.35, 1.0), 1.0 - exp(-8.0 * delta))

static func wheel_anchors(trailer: bool = false) -> Array:
	return [Vector3(-1.8, 0, 1.55), Vector3(1.8, 0, 1.55), Vector3(-1.8, 0, -1.55), Vector3(1.8, 0, -1.55)] if trailer else ANCHORS

static func steering_angles(steer: float, speed: float, trailer: bool = false) -> Vector2:
	var angle := clampf(steer, -1, 1) * 0.55 / (1.0 + absf(speed) * 0.014)
	if absf(angle) < 0.00001:
		return Vector2.ZERO
	var wheelbase := 3.1 if trailer else FRONT_Z - REAR_Z
	var half_track := 1.8 if trailer else HALF_TRACK
	var radius := wheelbase / tan(absf(angle))
	var inner := atan(wheelbase / maxf(0.1, radius - half_track))
	var outer := atan(wheelbase / (radius + half_track))
	return Vector2(outer, inner) * signf(angle) if angle > 0 else Vector2(inner, outer) * signf(angle)
