extends RefCounted

static func _unit(seed_value: int, salt: int) -> float:
	var value := (seed_value ^ salt) & 0xffffffff
	value = ((value ^ (value >> 16)) * 0x21f0aaad) & 0xffffffff
	value = ((value ^ (value >> 15)) * 0x735a2d97) & 0xffffffff
	return float((value ^ (value >> 15)) & 0xffffffff) / 4294967296.0

static func _smooth(value: float, reference: float) -> float:
	var ratio := clampf(absf(value) / reference, 0.0, 1.0)
	return ratio * ratio * (3.0 - 2.0 * ratio)

static func spread(player: Dictionary) -> float:
	return minf(0.09, 0.00045 + _smooth(player.speed, 9.2) * 0.055 + _smooth(player.get("yaw_velocity", 0.0), 1.36) * 0.022 + _smooth(player.get("slip_angle", 0.0), 0.35) * 0.032)

static func aim(origin: Vector3, target: Vector3, player: Dictionary, sample: float) -> Vector3:
	var angle := (clampf(sample, 0.0, 1.0) * 2.0 - 1.0) * spread(player)
	var offset := target - origin
	return origin + Vector3(offset.x * cos(angle) + offset.z * sin(angle), offset.y, offset.z * cos(angle) - offset.x * sin(angle))

static func profile(player: Dictionary, team: String, seed_value: int) -> Dictionary:
	var speed := absf(float(player.speed)) if team == "player" else 12.0
	var turn: float = player.get("yaw_velocity", 0.0) if team == "player" else 0.0
	var slip: float = player.get("slip_angle", 0.0) if team == "player" else 0.0
	var nitro: float = player.get("nitro_timer", 0.0) if team == "player" else 0.0
	nitro = 0.72 + minf(1.0, nitro / 1.85) * 0.28 if nitro > 0 else 0.0
	var speed_ratio := clampf(speed / 12.0, 0.0, 1.0)
	var turn_ratio := clampf(absf(turn) / 1.4, 0.0, 1.0)
	var moving_slip := clampf(absf(slip) / 0.35, 0.0, 1.0) * speed_ratio
	var motion := clampf(speed_ratio * 0.68 + turn_ratio * (0.08 + speed_ratio * 0.92) * 0.14 + moving_slip * 0.18 + nitro * 0.72, 0.0, 1.0)
	return {"phase": _unit(seed_value, 0x1b873593) * TAU,
		"angular_speed": (8.5 + speed_ratio * 4.8 + turn_ratio * 1.8 + moving_slip * 1.6 + nitro * 5.5) * (0.94 + _unit(seed_value, 0x51ed270b) * 0.12),
		"amplitude": 0.38 * motion, "decay": maxf(0.72, 0.9 + speed_ratio * 0.42 + turn_ratio * 0.18 + moving_slip * 0.15 - nitro * 0.26),
		"direction": (-1 if turn < 0 else 1) if absf(turn) > 0.01 else (-1 if _unit(seed_value, 0x85ebca6b) < 0.5 else 1)}

static func sample(profile_data: Dictionary, age: float) -> Vector2:
	var amplitude: float = profile_data.amplitude * (1.0 - exp(-16.0 * age)) * exp(-profile_data.decay * age)
	var phase: float = profile_data.phase + profile_data.direction * profile_data.angular_speed * age
	return Vector2(cos(phase), sin(phase)) * amplitude

static func move(shot: Dictionary, delta: float) -> void:
	shot.base_position += shot.velocity * delta
	shot.position = shot.base_position
	shot.rocket_age += delta
	var forward: Vector3 = shot.velocity.normalized()
	var reference := Vector3.UP if absf(forward.y) < 0.92 else Vector3.RIGHT
	var side := forward.cross(reference).normalized()
	var up := side.cross(forward).normalized()
	var offset := sample(shot.rocket_profile, shot.rocket_age)
	shot.position += side * offset.x + up * offset.y
