extends RefCounted
const Terrain = preload("res://modules/caravan/terrain_surface.gd")

static func advance(enemy: Dictionary, pose: Dictionary, delta: float, elapsed: float) -> Dictionary:
	var type := str(enemy.get("type", "soldier"))
	var speed := float(enemy.get("visual_effective_speed", enemy.get("speed", 0.0)))
	var wheel_rate := 1.6 if type in ["bike", "buggy"] else 1.35 * float(enemy.get("visual_throttle", 1.0)) if type == "priorityVehicle" else 1.0
	pose.wheel_angle = float(pose.get("wheel_angle", 0.0)) + speed * delta * wheel_rate
	pose.rotor_angle = float(pose.get("rotor_angle", 0.0)) + delta * (34.0 if enemy.get("kind") == "kamikaze" else 28.0)
	pose.phase = enemy.get("phase_animation", 0.0)
	for key in ["move_blend", "gait_direction", "animation_time", "attack_animation"]:
		pose[key] = enemy.get(key, 1.0 if key == "gait_direction" else 0.0)
	pose.instance_index = pose.get("instance_index", enemy.id)
	pose.components = {}
	for component: Dictionary in enemy.get("components", []):
		pose.components[component.kind] = component.get("exposed", false) and not component.get("dead", false)
	var pulse := sin(clampf(float(enemy.get("hit_time", 0.0)) * 6.0, 0.0, 1.0) * PI)
	var scale_value := 1.0 + pulse * (0.12 if type == "soldier" else 0.07 if type == "drone" else 0.06 if type in ["bike", "buggy"] else 0.055 if type in ["garrison", "priorityVehicle"] else 0.045)
	var scale_vector := Vector3(scale_value, 1.0 / scale_value, scale_value) if type == "soldier" else Vector3.ONE * scale_value
	var point: Vector3 = enemy.position
	if type == "drone":
		point.y = float(enemy.get("height", 4.8))
	elif type in ["bike", "buggy", "priorityVehicle"]:
		point.y = sin(elapsed * (9.0 if type == "bike" else 6.0 if type == "buggy" else 5.0) + float(enemy.get("yaw", 0.0))) * 0.035
	point.y += Terrain.height_at(point.x, point.z)
	return {"position": point, "basis": Basis(Vector3.BACK, float(enemy.get("roll", 0.0))).scaled(scale_vector), "pose": pose}
