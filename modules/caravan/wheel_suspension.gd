extends RefCounted

const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const FRONT_Z := Dimensions.WHEEL_FRONT_Z
const REAR_Z := -Dimensions.WHEEL_FRONT_Z
const HALF_TRACK := Dimensions.WHEEL_HALF_TRACK
const RADIUS := 0.88
const ANCHORS := [Vector3(-HALF_TRACK, 0, FRONT_Z), Vector3(HALF_TRACK, 0, FRONT_Z), Vector3(-HALF_TRACK, 0, REAR_Z), Vector3(HALF_TRACK, 0, REAR_Z)]
const TRAVEL := 0.48
const STRUT_LENGTH := 0.66
const SPRING_STIFFNESS := 45.0
const SPRING_DAMPING := 7.0
const AIR_ANGULAR_DAMPING := 1.5
const MAX_SUPPORT_SPEED := 6.0
const GRAVITY := 9.81
const REST_COMPRESSION := GRAVITY / SPRING_STIFFNESS
const MAX_TERRAIN_TILT := PI / 4.0
const PITCH_PER_ACCELERATION := 0.007
const MAX_LOAD_PITCH := 0.055
const PITCH_SPRING := 100.0
const PITCH_DAMPING := 20.0
const INTEGRATION_HZ := 120.0
const TRAILER_PITCH_FACTOR := 0.65

static func create() -> Dictionary:
	return {"initialized": false, "grounds": PackedFloat32Array(), "height": 0.0, "velocity": 0.0, "pitch": 0.0, "roll": 0.0, "pitch_velocity": 0.0, "roll_velocity": 0.0, "last_speed": 0.0, "wheel_offsets": PackedFloat32Array([0, 0, 0, 0]), "wheel_contacts": [true, true, true, true], "contacts": 4, "grip": 1.0, "slope": 0.0}

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
		state.grounds = grounds.duplicate()
		state.height = average
		state.last_speed = speed
		state.initialized = true
	var previous_grounds: PackedFloat32Array = state.grounds
	state.grounds = grounds.duplicate()
	var ground_velocities := PackedFloat32Array()
	for index in anchors.size():
		ground_velocities.append(clampf((grounds[index] - previous_grounds[index]) / delta, -MAX_SUPPORT_SPEED, MAX_SUPPORT_SPEED))
	var wheelbase: float = (anchors[0].z - anchors[2].z) * scale_factor
	var target_pitch := -atan2((grounds[0] + grounds[1] - grounds[2] - grounds[3]) * 0.5, wheelbase)
	var track: float = (anchors[1].x - anchors[0].x) * scale_factor
	var target_roll := clampf(atan2((grounds[1] + grounds[3] - grounds[0] - grounds[2]) * 0.5, track), -MAX_TERRAIN_TILT, MAX_TERRAIN_TILT)
	var terrain_pitch := clampf(atan(tan(target_pitch) * cos(target_roll)), -MAX_TERRAIN_TILT, MAX_TERRAIN_TILT)
	var acceleration := (speed - float(state.last_speed)) / delta
	var load_pitch := clampf(-acceleration * PITCH_PER_ACCELERATION, -MAX_LOAD_PITCH, MAX_LOAD_PITCH)
	if trailer:
		load_pitch *= TRAILER_PITCH_FACTOR
	state.last_speed = speed
	state.slope = -sin(target_pitch)
	var steps := maxi(1, ceili(delta * INTEGRATION_HZ))
	var dt := delta / steps
	for substep in steps:
		var old_tilt := body_basis(state)
		var support := float(state.contacts) / anchors.size()
		var angular_damping := lerpf(AIR_ANGULAR_DAMPING, PITCH_DAMPING, support)
		state.pitch_velocity += ((terrain_pitch + load_pitch - float(state.pitch)) * PITCH_SPRING * support - float(state.pitch_velocity) * angular_damping) * dt
		state.pitch = clampf(float(state.pitch) + float(state.pitch_velocity) * dt, -MAX_TERRAIN_TILT - MAX_LOAD_PITCH, MAX_TERRAIN_TILT + MAX_LOAD_PITCH)
		state.roll_velocity += ((target_roll - float(state.roll)) * PITCH_SPRING * support - float(state.roll_velocity) * angular_damping) * dt
		state.roll += state.roll_velocity * dt
		var tilt := body_basis(state)
		var force := 0.0
		var contacts := 0
		for index in 4:
			var mount_height: float = state.height + mount_offset(tilt, anchors[index]) * scale_factor
			var ground := lerpf(previous_grounds[index], grounds[index], float(substep + 1) / steps)
			var ground_velocity := ground_velocities[index]
			# Damp relative spring motion, retaining the upward impulse from a moving support.
			var angular_velocity := (mount_offset(tilt, anchors[index]) - mount_offset(old_tilt, anchors[index])) * scale_factor / dt
			var displacement := ground - mount_height
			var compression := REST_COMPRESSION + displacement
			state.wheel_contacts[index] = displacement >= -TRAVEL * scale_factor and compression > 0.0
			if state.wheel_contacts[index]:
				contacts += 1
				force += maxf(0.0, SPRING_STIFFNESS * compression - SPRING_DAMPING * (state.velocity + angular_velocity - ground_velocity)) * 0.25
		state.contacts = contacts
		state.velocity += (force - GRAVITY) * dt
		state.height += state.velocity * dt
	# Resolve compression stops, then publish wheel travel from the final body pose.
	var final_tilt := body_basis(state)
	for index in 4:
		var minimum_height := grounds[index] - (mount_offset(final_tilt, anchors[index]) + TRAVEL) * scale_factor
		if state.height < minimum_height:
			state.height = minimum_height
			state.velocity = maxf(state.velocity, ground_velocities[index])
	state.contacts = 0
	for index in 4:
		var displacement := grounds[index] - float(state.height) - mount_offset(final_tilt, anchors[index]) * scale_factor
		# At zero spring load the hub hangs at free extension, not on distant terrain.
		state.wheel_offsets[index] = clampf(displacement / scale_factor, -minf(TRAVEL, REST_COMPRESSION / scale_factor), TRAVEL)
		state.wheel_contacts[index] = displacement >= -TRAVEL * scale_factor and REST_COMPRESSION + displacement > 0.0
		state.contacts += int(state.wheel_contacts[index])
	state.grip = lerpf(float(state.grip), clampf(float(state.contacts) / 4.0 * (1.0 - absf(state.velocity) * 0.065), 0.35, 1.0), 1.0 - exp(-8.0 * delta))

# Shared body rotation and vertical hub geometry for physics and rendering.
static func body_basis(state: Dictionary) -> Basis:
	return Basis(Vector3.BACK, float(state.get("roll", 0.0))) * Basis(Vector3.RIGHT, float(state.get("pitch", 0.0)))

static func mount_offset(tilt: Basis, anchor: Vector3) -> float:
	return (tilt * (anchor + Vector3.UP * RADIUS)).y - RADIUS

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
