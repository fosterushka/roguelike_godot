extends RefCounted

static func capture(position: Vector3, heading: float, scale_value: float, speed: float, steer: float, wheel_angle: float, suspension: Dictionary) -> Dictionary:
	return {"position": position, "heading": heading, "scale": scale_value, "speed": speed, "steer": steer, "wheel_angle": wheel_angle, "suspension": suspension.duplicate(true)}

static func interpolate(previous: Dictionary, current: Dictionary, fraction: float) -> Dictionary:
	if previous.is_empty():
		return current.duplicate(true)
	var alpha := clampf(fraction, 0.0, 1.0)
	var pose := current.duplicate(true)
	pose.position = Vector3(previous.position).lerp(current.position, alpha)
	pose.heading = lerp_angle(previous.heading, current.heading, alpha)
	pose.wind_roll = lerpf(float(previous.get("wind_roll", 0.0)), float(current.get("wind_roll", 0.0)), alpha)
	for field in ["scale", "speed", "steer", "wheel_angle"]:
		pose[field] = lerpf(previous[field], current[field], alpha)
	pose.suspension.pitch = lerpf(float(previous.suspension.pitch), float(current.suspension.pitch), alpha)
	for index in 4:
		pose.suspension.wheel_offsets[index] = lerpf(previous.suspension.wheel_offsets[index], current.suspension.wheel_offsets[index], alpha)
	return pose

static func transform(pose: Dictionary) -> Transform3D:
	return Transform3D((Basis(Vector3.UP, pose.heading) * Basis(Vector3.BACK, float(pose.get("wind_roll", 0.0))) * Basis(Vector3.RIGHT, float(pose.suspension.pitch))).scaled(Vector3.ONE * float(pose.scale)), pose.position)
