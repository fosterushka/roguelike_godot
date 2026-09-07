extends RefCounted

static func vectors(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func prepare(bindings: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in bindings:
		var binding := entry.duplicate()
		binding.position = vectors(entry.position)
		binding.rotation = vectors(entry.rotation)
		binding.scale = vectors(entry.scale)
		binding.rest_inverse = matrix(entry.matrix).affine_inverse()
		binding.parent_transform = matrix(entry.parentMatrix)
		result.append(binding)
	return result

static func matrix(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[4], values[5], values[6]), Vector3(values[8], values[9], values[10])), Vector3(values[12], values[13], values[14]))

static func transform_for(part: Dictionary, pose: Dictionary) -> Transform3D:
	var rig: Dictionary = part.get("rig", {})
	if not rig.is_empty():
		return soldier(rig, pose)
	var correction := Transform3D.IDENTITY
	for binding: Dictionary in part.get("bindings", []):
		if binding.role == "boss_component":
			if not pose.get("components", {}).get(binding.kind, true):
				return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			continue
		var override: Dictionary = pose.get("binding_overrides", {}).get(binding.role, {})
		if not pose.get("warmup", false) and not override.get("visible", binding.get("initial_visible", true)):
			return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		var position: Vector3 = override.get("position", binding.position)
		var rotation: Vector3 = override.get("rotation", binding.rotation)
		var scale: Vector3 = override.get("scale", binding.scale)
		match str(binding.role):
			"wheel":
				rotation.x += float(pose.get("wheel_angle", 0.0))
				if pose.get("player", false):
					position.y = float(binding.get("baseY", position.y)) + sin(float(pose.get("wheel_phase", 0.0)) + float(binding.get("phase", 0.0))) * 0.045 * float(pose.get("speed_amount", 0.0))
			"jammer_head": rotation.y = float(pose.get("elapsed", 0.0)) * 2.4
			"jammer_scan": scale.z = 0.82 + (sin(float(pose.get("elapsed", 0.0)) * 7.2) + 1.0) * 0.18
			"jammer_pulse":
				var wave := (sin(float(pose.get("elapsed", 0.0)) * 5.4 - int(binding.get("pulse_index", 0)) * 1.2) + 1.0) * 0.5
				scale = Vector3(0.72 + wave * 0.45, 1.0, 0.72 + wave * 0.45)
			"rotor": rotation.y += float(pose.get("rotor_angle", 0.0))
			"weapon_pitch": rotation.x = float(pose.get("weapon_pitch", 0.0))
			"walker_leg":
				var speed := absf(float(pose.get("speed", 0.0)))
				var amount := minf(1.0, speed / 7.0)
				var phase := float(pose.get("elapsed", 0.0)) * (2.4 + speed * 0.72) + float(binding.get("phase", 0.0))
				rotation.x = sin(phase) * 0.48 * amount
				position.y = 1.12 + maxf(0.0, cos(phase)) * 0.13 * amount
		var changed := Transform3D(local_basis(rotation, scale), position)
		correction *= binding.parent_transform * changed * binding.rest_inverse
	return correction * part.get("transform", part.get("base", Transform3D.IDENTITY))

static func soldier(rig: Dictionary, pose: Dictionary) -> Transform3D:
	var position := vectors(rig.position)
	var rotation := vectors(rig.rotation)
	var scale := Vector3.ONE
	var move_blend := clampf(float(pose.get("move_blend", 0.0)), 0.0, 1.0)
	var phase := float(pose.get("phase", 0.0))
	var stride := sin(phase) * move_blend * float(pose.get("gait_direction", 1.0))
	var bounce := absf(cos(phase)) * move_blend
	var idle := sin(float(pose.get("animation_time", 0.0)) * 2.0 + float(pose.get("instance_index", 0)) * 0.37)
	var attack_life := clampf(float(pose.get("attack_animation", 0.0)), 0.0, 1.0)
	var attack := sin((1.0 - attack_life) * PI) if attack_life > 0.0 else 0.0
	var side := float(rig.get("side", 1.0))
	match str(rig.role):
		"body":
			position.y += bounce * 0.035 + idle * 0.01
			rotation.x += move_blend * 0.045 + attack * 0.04
			rotation.z += stride * 0.035
			scale.y += idle * 0.008
		"head":
			position.y += bounce * 0.05 + idle * 0.015
			rotation.x += attack * 0.08
			rotation.y += stride * 0.04
		"leg":
			var swing := stride * side * 0.68
			rotation.x += swing
			rotation.z += side * move_blend * 0.025
			position.y += maxf(0.0, -swing) * 0.045
		"arm":
			rotation.x -= stride * side * 0.5
			if rig.kind != "bomber":
				rotation.x -= 0.58 + attack * 0.72 if side > 0.0 else 0.78 + attack * 0.2
				rotation.z += -0.18 if side > 0.0 else 0.18
			elif side > 0.0:
				rotation.x -= attack * 1.25
			if pose.get("wave", false):
				rotation.x = -0.2
				rotation.z = side * (2.5 + sin(float(pose.get("animation_time", 0)) * 9 + side) * 0.35)
			elif pose.get("climbing", false):
				rotation.x = -2.4
				rotation.z = side * 0.3
		"weapon":
			if rig.kind != "bomber":
				rotation.x -= 0.72 + attack * 0.22
				rotation.z += stride * 0.08
			else:
				rotation.x += -stride * 0.5 - attack * 1.25
	return Transform3D(local_basis(rotation, scale), position)

static func local_basis(rotation: Vector3, scale_value: Vector3) -> Basis:
	var basis := Basis.from_euler(rotation, EULER_ORDER_XYZ)
	return Basis(basis.x * scale_value.x, basis.y * scale_value.y, basis.z * scale_value.z)
